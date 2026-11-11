require "test_helper"

class StudioAiSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    suffix = SecureRandom.hex(5)
    @password = "fictional-ai-http-test-password"
    @owner = User.create!(email: "settings-owner-#{suffix}@example.test", role: "owner",
      password: @password, password_confirmation: @password)
    @outsider = User.create!(email: "settings-foreign-#{suffix}@example.test", role: "owner",
      password: @password, password_confirmation: @password)
    @ws = Workspace.create!(owner_user: @owner, name: "Fictional workspace",
      slug: "settings-#{suffix}")
    @foreign = Workspace.create!(owner_user: @outsider, name: "Fictional other",
      slug: "settings-other-#{suffix}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @outsider, role: "owner", status: "active")
    client = @ws.clients.create!(display_name: "Synthetic reviewer")
    @intake = @ws.project_intakes.create!(client: client,
      title: "Synthetic offline policy", project_type: "website",
      goal: "Fictional requirements for no-network planning",
      demo_consent_at: Time.current)
  end

  test "guest redirected and other workspace owner denied with no policy leakage" do
    get path
    assert_redirected_to sign_in_path
    sign_in(@outsider)
    get path
    assert_response :not_found
    patch path, params: { scope: "workspace", policy: { mode: "offline" } }
    assert_response :not_found
    assert_equal 0, Studio::AiPolicy.count
  end

  test "exact owner saves workspace policy and project-only restrictions" do
    sign_in(@owner)
    get path
    assert_response :success
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_match(/External providers: blocked/, response.body)

    patch path, params: { scope: "workspace",
      policy: { mode: "offline", document_plan: "1", synthetic: "1" } }
    assert_redirected_to path
    workspace_policy = @ws.studio_ai_policies.find_by!(project_intake_id: nil)
    assert_equal "offline", workspace_policy.mode
    assert_equal ["document_plan"], workspace_policy.allowed_purposes
    assert_equal ["synthetic"], workspace_policy.allowed_data_classes

    patch path, params: { scope: "project",
      policy: { mode: "off", document_plan: "1", synthetic: "1" } }
    assert_redirected_to path
    project_policy = @ws.studio_ai_policies.find_by!(project_intake_id: @intake.id)
    assert_equal "off", project_policy.mode
    result = Studio::OfflineAiDispatcher.new(actor: @owner, workspace: @ws, intake: @intake)
      .call(purpose: "document_plan", data_class: "synthetic")
    assert_equal "project_restriction", result.fetch(:reason)
  end

  test "forged scope or mode fails without creating a provider grant" do
    sign_in(@owner)
    patch path, params: { scope: "global", policy: { mode: "offline" } }
    assert_response :unprocessable_entity
    patch path, params: { scope: "workspace", policy: {
      mode: "external_unlimited", document_plan: "1", synthetic: "1",
      max_cost: "9999", provider_key: "must-be-ignored"
    } }
    assert_response :unprocessable_entity
    assert_equal 0, Studio::AiPolicy.count
  end

  test "revoked membership and foreign project id have no access" do
    sign_in(@owner)
    get workspace_ai_settings_path(@foreign, @intake)
    assert_response :not_found
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    get path
    assert_response :not_found
    patch path, params: { scope: "workspace", policy: { mode: "offline" } }
    assert_response :not_found
  end

  test "production feature gate returns 404 even to signed owner" do
    sign_in(@owner)
    Rails.env.stub(:production?, true) do
      get path
      assert_response :not_found
      patch path, params: { scope: "workspace", policy: { mode: "offline" } }
      assert_response :not_found
    end
    assert_equal 0, Studio::AiPolicy.count
  end

  private

  def path
    workspace_ai_settings_path(@ws, @intake)
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @password }
    assert_redirected_to consultations_path
  end
end
