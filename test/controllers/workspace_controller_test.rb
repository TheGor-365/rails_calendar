require "test_helper"

class WorkspaceControllerTest < ActionDispatch::IntegrationTest
  test "anonymous cannot read private workspace" do
    get workspace_url
    assert_redirected_to sign_in_url
    assert_no_match(/Рабочее пространство/, response.body)
  end

  test "owner receives real module links and signed-out session loses access" do
    owner = User.create!(email: "workspace-owner@example.test", role: "owner",
                         password: "long-workspace-password-2026")
    post account_session_url, params: { email: owner.email, password: "long-workspace-password-2026" }
    assert_redirected_to workspace_url
    get workspace_url
    assert_response :success
    assert_select "h1", text: "Workspace"
    assert_select ".ws-hub-metric", count: 3
    assert_select ".ws-hub-tools", count: 0
    assert_select ".ws-hub-header a[href=?]", admin_project_intakes_path, count: 1
    assert_select ".ws-hub-panel a[href=?]", consultations_path
    assert_select ".app-header a[href=?]", root_path
    assert_select ".app-header a[href=?]", admin_project_intakes_path
    assert_select ".app-brand[href=?]", workspace_path
    delete sign_out_url
    assert_redirected_to root_url
    get workspace_url
    assert_redirected_to sign_in_url
  end

  test "owner mobile dock has five links with logout in the header" do
    owner = User.create!(email: "qa-mobile-owner@example.test", role: "owner",
                         password: "qa-mobile-owner-password-2026")
    post account_session_url, params: {email: owner.email, password: "qa-mobile-owner-password-2026"}
    assert_redirected_to workspace_url
    get workspace_url
    assert_response :success
    assert_select "nav.rc-mobile-dock--owner a.rc-mobile-dock-item", count: 5
    assert_select "nav.rc-mobile-dock--owner form[action=?]", sign_out_path, count: 0
    assert_select "header.app-header form[action=?]", sign_out_path, count: 1
  end

  test "client dock has three links and sign-out remains in the header" do
    client = User.create!(email: "qa-mobile-client@example.test", role: "client",
                          password: "qa-mobile-client-password-2026",
                          email_verified_at: Time.current, signup_consent_at: Time.current,
                          signup_policy_version: "qa-mobile-2026")
    post account_session_url, params: {email: client.email, password: "qa-mobile-client-password-2026"}
    assert_redirected_to client_home_path
    get client_cabinet_path
    assert_response :success
    assert_select "nav.rc-mobile-dock--client a.rc-mobile-dock-item", count: 2
    assert_select "nav.rc-mobile-dock--client form[action=?]", sign_out_path, count: 0
    assert_select "header.app-header form[action=?]", sign_out_path, count: 1

    old_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    begin
      ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
      get client_cabinet_path
      assert_response :success
      assert_select "nav.rc-mobile-dock--client a.rc-mobile-dock-item", count: 3
      assert_select "nav.rc-mobile-dock--client form[action=?]", sign_out_path, count: 0
    ensure
      ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = old_pilot
    end
  end

  test "guest public services has no owner workspace links" do
    get services_url
    assert_response :success
    assert_select "a[href='/workspace']", count: 0
  end

  test "workspace view never changes consultation or intake counts" do
    owner = User.create!(email: "workspace-readonly@example.test", role: "owner",
                         password: "long-workspace-password-2026")
    post account_session_url, params: { email: owner.email, password: "long-workspace-password-2026" }
    assert_no_difference ["Consultation.count", "ProjectIntake.count", "Workspace.count"] do
      get workspace_url
    end
    assert_response :success
  end
end
