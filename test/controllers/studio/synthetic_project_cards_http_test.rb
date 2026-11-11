require "test_helper"

class StudioSyntheticProjectCardsHttpTest < ActionDispatch::IntegrationTest
  setup do
    tag = SecureRandom.hex(5)
    @password = "rc039-http-fictional-owner-password"
    @owner = User.create!(email: "rc039-http-owner-#{tag}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @foreign_owner = User.create!(email: "rc039-http-foreign-#{tag}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @ws = Workspace.create!(owner_user: @owner,
      name: "Fictional Project Hub HTTP", slug: "rc039-http-#{tag}")
    @foreign_ws = Workspace.create!(owner_user: @foreign_owner,
      name: "Foreign fictional HTTP", slug: "rc039-http-other-#{tag}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_ws, user: @foreign_owner,
      role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Hidden fictional customer name")
    @another_client = @ws.clients.create!(display_name: "Other hidden customer")
    @intake = intake_for(@ws, @client)
    @another_intake = intake_for(@ws, @another_client)
    @foreign_client = @foreign_ws.clients.create!(display_name: "Hidden foreign customer")
    @foreign_intake = intake_for(@foreign_ws, @foreign_client)
  end

  test "guest and foreign owner cannot list or write fictional cards" do
    get hub_path
    assert_redirected_to sign_in_path
    assert_no_difference "Studio::SyntheticProjectCard.count" do
      post cards_path, params: { artifact_key: "requirements_spec" }
    end
    assert_redirected_to sign_in_path

    sign_in(@foreign_owner)
    get hub_path
    assert_response :not_found
    assert_no_difference "Studio::SyntheticProjectCard.count" do
      post cards_path, params: { artifact_key: "requirements_spec" }
    end
    assert_response :not_found
  end

  test "owner reads nine closed board cards and only scoped persisted metadata" do
    sign_in(@owner)
    assert_no_difference ["Studio::SyntheticProjectCard.count",
                          "Studio::SyntheticProjectCardTransition.count",
                          "ClientFact.count"] do
      get hub_path
    end
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 9, payload.dig("board", "card_count")
    assert_equal 9, payload.dig("board", "blocked_card_count")
    assert_equal [], payload.fetch("cards")
    assert_equal false, payload.dig("board", "document_generation_allowed")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal "nosniff", response.headers.fetch("X-Content-Type-Options")
    refute_includes response.body, @intake.title
    refute_includes response.body, @intake.goal
    refute_includes response.body, @client.display_name
  end

  test "owner creates idempotent card; malicious approval and source params are ignored" do
    sign_in(@owner)
    assert_difference "Studio::SyntheticProjectCard.count", 1 do
      post cards_path, params: {
        artifact_key: "requirements_spec", state: "approved",
        approved: "true", source_content: "FORGED PRIVATE FILE BYTES",
        client_confirmed: "true", external_ai: "openai"
      }
    end
    assert_response :created
    card = JSON.parse(response.body).fetch("card")
    assert_equal "backlog", card.fetch("state")
    assert_equal false, card.fetch("document_generation_allowed")
    assert_equal false, card.fetch("client_confirmed")
    assert_equal 0, card.fetch("version")
    assert_not_includes response.body, "FORGED PRIVATE FILE BYTES"

    assert_no_difference "Studio::SyntheticProjectCard.count" do
      post cards_path, params: { artifact_key: "requirements_spec" }
      assert_response :created
    end
    assert_equal card, JSON.parse(response.body).fetch("card")
    get hub_path
    assert_equal [card], JSON.parse(response.body).fetch("cards")
    assert_equal 0, Studio::SyntheticProjectCardTransition.count
  end

  test "versioned transition records audit and refuses stale or forbidden states" do
    sign_in(@owner)
    card = create_card
    assert_difference "Studio::SyntheticProjectCardTransition.count", 1 do
      patch card_path(card.fetch("card_id")), params: {
        expected_state: "backlog", expected_version: "0",
        to_state: "in_review", state: "approved", scope_approved: "true"
      }
    end
    assert_response :success
    changed = JSON.parse(response.body).fetch("card")
    assert_equal "in_review", changed.fetch("state")
    assert_equal 1, changed.fetch("version")
    assert_equal false, changed.fetch("scope_approved")
    assert_equal 1, Studio::SyntheticProjectCardTransition.count

    assert_no_difference "Studio::SyntheticProjectCardTransition.count" do
      patch card_path(card.fetch("card_id")), params: {
        expected_state: "backlog", expected_version: "0", to_state: "in_review"
      }
    end
    assert_response :conflict

    [{expected_state: "in_review", expected_version: "1", to_state: "approved"},
     {expected_state: "in_review", expected_version: "abc", to_state: "on_hold"},
     {expected_state: "in_review", expected_version: "-1", to_state: "on_hold"},
     {expected_state: "in_review", expected_version: "1", to_state: "in_review"}].each do |invalid|
      assert_no_difference "Studio::SyntheticProjectCardTransition.count" do
        patch card_path(card.fetch("card_id")), params: invalid
      end
      assert_response :unprocessable_entity
    end
    assert_equal "in_review", Studio::SyntheticProjectCard.find(card.fetch("card_id")).state
  end

  test "same-workspace swapped client, foreign intake and revoked owner fail closed" do
    sign_in(@owner)
    card = create_card
    [
      hub_path(client: @another_client),
      hub_path(intake: @another_intake),
      hub_path(workspace: @foreign_ws, client: @foreign_client, intake: @foreign_intake)
    ].each do |path|
      get path
      assert_response :not_found
    end
    assert_no_difference "Studio::SyntheticProjectCard.count" do
      post cards_path(client: @another_client), params: { artifact_key: "qa_plan" }
    end
    assert_response :not_found
    assert_no_difference "Studio::SyntheticProjectCardTransition.count" do
      patch card_path(card.fetch("card_id"), client: @another_client), params: {
        expected_state: "backlog", expected_version: "0", to_state: "in_review"
      }
    end
    assert_response :not_found

    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    get hub_path
    assert_response :not_found
    assert_no_difference "Studio::SyntheticProjectCardTransition.count" do
      patch card_path(card.fetch("card_id")), params: {
        expected_state: "backlog", expected_version: "0", to_state: "in_review"
      }
    end
    assert_response :not_found
  end

  test "production and non-test modes block reads and writes without exception" do
    sign_in(@owner)
    Rails.env.stub(:production?, true) do
      get hub_path
      assert_response :not_found
      assert_no_difference "Studio::SyntheticProjectCard.count" do
        post cards_path, params: { artifact_key: "requirements_spec" }
      end
      assert_response :not_found
    end
    Rails.env.stub(:test?, false) do
      get hub_path
      assert_response :not_found
      assert_no_difference "Studio::SyntheticProjectCard.count" do
        post cards_path, params: { artifact_key: "requirements_spec" }
      end
      assert_response :not_found
    end
  end

  test "CSRF protection rejects untrusted HTTP mutation even with owner session" do
    sign_in(@owner)
    previous = ActionController::Base.allow_forgery_protection
    previous_origin = ActionController::Base.forgery_protection_origin_check
    begin
      ActionController::Base.allow_forgery_protection = true
      ActionController::Base.forgery_protection_origin_check = true
      get hub_path
      assert_response :success
      assert_no_difference "Studio::SyntheticProjectCard.count" do
        assert_raises(ActionController::InvalidAuthenticityToken) do
          post cards_path, params: { artifact_key: "requirements_spec" }
        end
      end
    ensure
      ActionController::Base.allow_forgery_protection = previous
      ActionController::Base.forgery_protection_origin_check = previous_origin
    end
  end

  private

  def intake_for(ws, client)
    ws.project_intakes.create!(client: client, title: "Hidden fictional project title",
      project_type: "website", goal: "Private fictional project goal not exposed through JSON.",
      demo_consent_at: Time.current)
  end

  def hub_path(workspace: @ws, client: @client, intake: @intake)
    "/workspaces/#{workspace.id}/clients/#{client.id}/project_intakes/#{intake.id}/project_hub"
  end

  def cards_path(workspace: @ws, client: @client, intake: @intake)
    "#{hub_path(workspace: workspace, client: client, intake: intake)}/cards"
  end

  def card_path(id, workspace: @ws, client: @client, intake: @intake)
    "#{cards_path(workspace: workspace, client: client, intake: intake)}/#{id}"
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @password }
    assert_redirected_to consultations_path
  end

  def create_card
    post cards_path, params: { artifact_key: "requirements_spec" }
    assert_response :created
    JSON.parse(response.body).fetch("card")
  end
end
