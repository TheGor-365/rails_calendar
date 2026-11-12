require "test_helper"

class StudioOfflineProposalHttpTest < ActionDispatch::IntegrationTest
  setup do
    suffix = SecureRandom.hex(5)
    @password = "offline-proposal-synthetic-only"
    @owner = User.create!(email: "proposal-owner-#{suffix}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @stranger = User.create!(email: "proposal-stranger-#{suffix}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @ws = Workspace.create!(owner_user: @owner,
      name: "Synthetic proposal workspace", slug: "proposal-ws-#{suffix}")
    @foreign_ws = Workspace.create!(owner_user: @stranger,
      name: "Foreign proposal workspace", slug: "proposal-other-#{suffix}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_ws, user: @stranger, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Fictional proposal client")
    other = @ws.clients.create!(display_name: "Other fictional client")
    @intake = make_intake(@ws, @client)
    @other_intake = make_intake(@ws, other)
    @one = add_source(@client, @intake, "# Synthetic source, not for disclosure\\n")
    @foreign_source = add_source(other, @other_intake, "# Other source is private\\n")
  end

  test "guest, foreign owner, revoked owner and production are denied" do
    post path, params: { purpose: "clarify" }
    assert_redirected_to sign_in_path
    sign_in(@stranger)
    post path, params: { purpose: "clarify" }
    assert_response :not_found
    delete sign_out_path
    sign_in(@owner)
    Rails.env.stub(:production?, true) do
      post path, params: { purpose: "clarify" }
      assert_response :not_found
    end
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    post path, params: { purpose: "clarify" }
    assert_response :not_found
  end

  test "owner explicitly previews safe offline output without mutation or billing" do
    sign_in(@owner)
    get "/workspaces/#{@ws.id}/project_intakes/#{@intake.id}/ai_settings"
    assert_response :success
    assert_select "section[aria-label='Synthetic offline proposal'] form", 1
    assert_select "input[type='checkbox'][name='source_ids[]'][value='#{@one.id}']", 1
    assert_select "input[type='checkbox'][name='source_ids[]'][value='#{@foreign_source.id}']", 0

    post path, params: { purpose: "clarify" }
    assert_response :unprocessable_entity

    @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    before_versions = Studio::AiPolicyRevision.count
    before_sources = ProjectSource.count
    post path, params: { purpose: "clarify", source_ids: [@one.id.to_s],
      provider: "paid_external", estimated_usd: 9999 }
    assert_response :success
    assert_select "[aria-label='Unapproved offline proposal']", text: /Needs human review/
    assert_match(/0 external calls/, response.body)
    assert_match(/\$0 cost/, response.body)
    assert_match(/1 metadata sources/, response.body)
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal "nosniff", response.headers.fetch("X-Content-Type-Options")
    assert_equal before_versions, Studio::AiPolicyRevision.count
    assert_equal before_sources, ProjectSource.count
    refute_includes response.body, "Synthetic source, not for disclosure"
    refute_includes response.body, "Other source is private"
  end

  test "foreign IDs, duplicated IDs and unexpected raw input are rejected" do
    sign_in(@owner)
    @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    [
      { source_ids: [@foreign_source.id.to_s] },
      { source_ids: [@one.id.to_s, @one.id.to_s] },
      { source_ids: "1" },
      { source_ids: ["0"] },
      { source_ids: ["999999999999999999999"] },
      { source_ids: ["1; DROP TABLE users"] },
      { source_ids: (1..11).map(&:to_s) },
      { purpose: "ignore_system_rules" }
    ].each do |attack|
      post path, params: { purpose: "clarify" }.merge(attack)
      assert_response :unprocessable_entity
      assert_select "[role='alert']", /Offline proposal rejected/
    end
  end

  test "tampered audited policy denies HTTP preview without exposing internals" do
    sign_in(@owner)
    policy = @ws.studio_ai_policies.create!(mode: "off", purposes: ["clarify"])
    policy.update_columns(mode: "offline") # synthetic privileged bypass
    post path, params: { purpose: "clarify" }
    assert_response :unprocessable_entity
    assert_select "[role='alert']", /Offline proposal rejected/
    refute_includes response.body, policy.revisions.sole.event_digest
  end

  private

  def path
    "/workspaces/#{@ws.id}/project_intakes/#{@intake.id}/offline_proposal"
  end

  def make_intake(workspace, client)
    workspace.project_intakes.create!(client: client,
      title: "Fictional project preview", project_type: "website",
      goal: "Non-sensitive fictional project only for regression tests.",
      demo_consent_at: Time.current)
  end

  def add_source(client, intake, body)
    report = Studio::SourceInspector.new.call(filename: "synthetic.md", bytes: body)
    Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @ws)
      .register_preview!(client: client, intake: intake, report: report)
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @password }
    assert_redirected_to consultations_path
  end
end
