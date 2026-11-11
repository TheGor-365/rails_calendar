require "test_helper"

class StudioAiSettingsHttpTest < ActionDispatch::IntegrationTest
  setup do
    nonce = SecureRandom.hex(5)
    @pass = "rc037-synthetic-settings-http-password"
    @owner = User.create!(email: "rc037-ui-owner-#{nonce}@example.test",
      role: "owner", password: @pass, password_confirmation: @pass)
    @other = User.create!(email: "rc037-ui-foreign-#{nonce}@example.test",
      role: "owner", password: @pass, password_confirmation: @pass)
    @ws = Workspace.create!(owner_user: @owner, name: "RC037 owner studio", slug: "rc037-ui-#{nonce}")
    @foreign = Workspace.create!(owner_user: @other, name: "Foreign studio", slug: "rc037-x-#{nonce}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @other, role: "owner", status: "active")
    client = @ws.clients.create!(display_name: "Fictional only")
    @intake = @ws.project_intakes.create!(client: client, title: "UI synthetic project",
      project_type: "website", goal: "A wholly fictional local UI test.",
      demo_consent_at: Time.current)
  end

  test "owner sees two explicit offline settings forms and saves restricted policy" do
    get path
    assert_redirected_to sign_in_path

    sign_in(@owner)
    get path
    assert_response :success
    assert_select "h1", "Offline AI settings"
    assert_select "section[aria-label='Workspace policy'] form", 1
    assert_select "section[aria-label='Project restriction'] form", 1
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal "nosniff", response.headers.fetch("X-Content-Type-Options")
    assert_no_difference "Studio::AiPolicy.count" do
      get path
    end

    assert_difference "Studio::AiPolicy.count", 1 do
      patch path, params: { target: "workspace", mode: "offline", purposes: %w[clarify source_outline] }
    end
    assert_redirected_to path
    root = @ws.studio_ai_policies.find_by!(project_intake_id: nil)
    assert_equal "offline", root.mode
    assert_equal %w[clarify source_outline], root.purposes
    assert_equal false, root.external_consent
    assert_equal 0, root.usd_cap_per_month

    assert_difference "Studio::AiPolicy.count", 1 do
      patch path, params: { target: "project", mode: "offline", purposes: ["clarify"],
        external_consent: true, usd_cap_per_month: 99999 }
    end
    assert_redirected_to path
    policy = @ws.studio_ai_policies.find_by!(project_intake_id: @intake.id)
    assert_equal false, policy.external_consent
    assert_equal 0, policy.usd_cap_per_month
    assert_equal ["clarify"], policy.purposes

    get path
    assert_response :success
    assert_select "[aria-label='Workspace policy revision history']", 1
    assert_select "[aria-label='Project restriction revision history']", 1
    assert_select "[aria-label='Workspace policy revision history']", text: /Revision 1/
    assert_select "[aria-label='Project restriction revision history']", text: /Revision 1/
    assert_not_includes response.body, root.revisions.sole.event_digest
    assert_not_includes response.body, @owner.email

    result = Studio::OfflineAiDispatcher.new(actor: @owner, workspace: @ws, intake: @intake)
      .call(purpose: "clarify")
    assert_equal 0, result[:external_calls]
    assert_equal 0, result[:billable_usd]
    assert_raises(Studio::OfflineAiDispatcher::Denied) do
      Studio::OfflineAiDispatcher.new(actor: @owner, workspace: @ws, intake: @intake)
        .call(purpose: "source_outline")
    end
  end

  test "invalid modes, purposes, targets and duplicate submission do not enable providers" do
    sign_in(@owner)
    [
      { target: "workspace", mode: "reviewed_provider", purposes: ["clarify"] },
      { target: "project", mode: "offline", purposes: ["unknown"] },
      { target: "workspace", mode: "offline", purposes: "clarify" },
      { target: "owner", mode: "offline", purposes: ["clarify"] },
      { target: "workspace", mode: "offline", purposes: %w[clarify clarify] }
    ].each do |data|
      assert_no_difference "Studio::AiPolicy.count" do
        patch path, params: data
      end
      assert_response :unprocessable_entity
      assert_select "[role='alert']", /Invalid offline-only setting/
    end
  end

  test "wrong workspace, other owner, revoked membership and production mode are forbidden" do
    sign_in(@other)
    get path
    assert_response :not_found
    patch path, params: { target: "workspace", mode: "offline", purposes: ["clarify"] }
    assert_response :not_found
    delete sign_out_path

    sign_in(@owner)
    get "/workspaces/#{@foreign.id}/project_intakes/#{@intake.id}/ai_settings"
    assert_response :not_found
    Rails.env.stub(:production?, true) do
      get path
      assert_response :not_found
      patch path, params: { target: "workspace", mode: "offline" }
      assert_response :not_found
    end
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    get path
    assert_response :not_found
    assert_equal 0, Studio::AiPolicy.count
  end

  private

  def path
    "/workspaces/#{@ws.id}/project_intakes/#{@intake.id}/ai_settings"
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @pass }
    assert_redirected_to consultations_path
  end
end
