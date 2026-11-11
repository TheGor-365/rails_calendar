require "test_helper"

class StudioSyntheticProjectHubUiHttpTest < ActionDispatch::IntegrationTest
  setup do
    salt = SecureRandom.hex(5)
    @password = "rc039-preview-owner-only-test-password"
    @owner = User.create!(email: "rc039-preview-#{salt}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @stranger = User.create!(email: "rc039-preview-foreign-#{salt}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @ws = Workspace.create!(owner_user: @owner, name: "Secret fictional board workspace",
      slug: "rc039-preview-#{salt}")
    @foreign_ws = Workspace.create!(owner_user: @stranger,
      name: "Foreign fictional board", slug: "rc039-preview-other-#{salt}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_ws, user: @stranger, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Hidden synthetic customer")
    @other_client = @ws.clients.create!(display_name: "Wrong synthetic customer")
    @intake = @ws.project_intakes.create!(client: @client, title: "Private fictional title",
      project_type: "website", goal: "A fictional goal not displayed by the board.",
      demo_consent_at: Time.current)
  end

  test "guest is redirected and other owner sees no board" do
    get preview_path
    assert_redirected_to sign_in_path
    assert_no_difference "Studio::SyntheticProjectCard.count" do
      post create_path, params: { artifact_key: "requirements_spec" }
    end
    assert_redirected_to sign_in_path

    sign_in(@stranger)
    get preview_path
    assert_response :not_found
    post create_path, params: { artifact_key: "requirements_spec" }
    assert_response :not_found
    assert_equal 0, Studio::SyntheticProjectCard.count
  end

  test "owner HTML presents four accessible lanes nine cards and secure no-store response" do
    sign_in(@owner)
    assert_no_difference ["Studio::SyntheticProjectCard.count", "ClientFact.count",
                          "Consultation.count"] do
      get preview_path
    end
    assert_response :success
    assert_select "h1", text: "Project Hub preview"
    assert_select "[aria-label='Project Hub workflow lanes']", 1
    assert_select "section.rc-hub-lane", 4
    assert_select "li.rc-hub-card", 9
    assert_select "form[action='#{create_path}']", 9
    assert_select "form input[name=artifact_key]", 9
    assert_select "details summary", 9
    assert_select "main#main-content", 1
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal "nosniff", response.headers.fetch("X-Content-Type-Options")
    refute_includes response.body, @intake.title
    refute_includes response.body, @intake.goal
    refute_includes response.body, @client.display_name
    assert_not_includes response.body, "Approve scope"
    assert_not_includes response.body, "Upload client file"
  end

  test "HTML owner actions create one fixed card then transition with versioned audit" do
    sign_in(@owner)
    assert_difference "Studio::SyntheticProjectCard.count", 1 do
      post create_path, params: {
        artifact_key: "requirements_spec",
        state: "approved", client_confirmed: "true",
        raw_file: "FORGED_PRIVATE_BYTES"
      }
    end
    assert_redirected_to preview_path
    assert_equal "backlog", Studio::SyntheticProjectCard.sole.state

    get preview_path
    assert_response :success
    assert_select "[data-artifact-key='requirements_spec'] form[action='#{card_path(Studio::SyntheticProjectCard.sole.id)}']", 1
    assert_select "[data-artifact-key='requirements_spec'] select[name=to_state]", 1
    refute_includes response.body, "FORGED_PRIVATE_BYTES"

    row = Studio::SyntheticProjectCard.sole
    assert_difference "Studio::SyntheticProjectCardTransition.count", 1 do
      patch card_path(row.id), params: {
        expected_state: "backlog", expected_version: "0", to_state: "in_review",
        scope_approved: "true"
      }
    end
    assert_redirected_to preview_path
    assert_equal "in_review", row.reload.state
    assert_equal 1, row.lock_version

    get preview_path
    assert_select "[data-artifact-key='requirements_spec']", text: /In review/
    assert_select "[data-artifact-key='requirements_spec']", text: /Revision 1/
    assert_no_difference "Studio::SyntheticProjectCardTransition.count" do
      patch card_path(row.id), params: {
        expected_state: "backlog", expected_version: "0", to_state: "in_review"
      }
    end
    assert_response :conflict
    assert_no_difference "Studio::SyntheticProjectCard.count" do
      post create_path, params: { artifact_key: "untrusted" }
    end
    assert_response :unprocessable_entity
  end

  test "same-workspace swapped client and revoked membership block HTML reads and writes" do
    sign_in(@owner)
    wrong_path = "/workspaces/#{@ws.id}/clients/#{@other_client.id}/project_intakes/#{@intake.id}/project_hub/preview"
    get wrong_path
    assert_response :not_found
    post "#{wrong_path}/cards", params: { artifact_key: "requirements_spec" }
    assert_response :not_found

    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    get preview_path
    assert_response :not_found
    post create_path, params: { artifact_key: "requirements_spec" }
    assert_response :not_found
    assert_equal 0, Studio::SyntheticProjectCard.count
  end

  test "hard denied under production or non-test environment predicates" do
    sign_in(@owner)
    Rails.env.stub(:production?, true) do
      get preview_path
      assert_response :not_found
      post create_path, params: { artifact_key: "requirements_spec" }
      assert_response :not_found
    end
    Rails.env.stub(:test?, false) do
      get preview_path
      assert_response :not_found
      post create_path, params: { artifact_key: "requirements_spec" }
      assert_response :not_found
    end
    assert_equal 0, Studio::SyntheticProjectCard.count
  end

  private

  def preview_path
    rc039_synthetic_project_hub_preview_path(@ws, @client, @intake)
  end

  def create_path
    rc039_synthetic_project_hub_preview_cards_path(@ws, @client, @intake)
  end

  def card_path(id)
    rc039_synthetic_project_hub_preview_card_path(@ws, @client, @intake, id)
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @password }
    assert_redirected_to consultations_path
  end
end
