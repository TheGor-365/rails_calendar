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
    assert_select ".ws-hub-tool[href=?]", root_path
    assert_select ".ws-hub-tool[href=?]", consultations_path
    assert_select ".ws-hub-tool[href=?]", admin_project_intakes_path
    assert_select ".ws-hub-tool[href=?]", new_project_intake_path
    assert_select ".app-brand[href=?]", workspace_path
    delete sign_out_url
    assert_redirected_to root_url
    get workspace_url
    assert_redirected_to sign_in_url
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
    assert_no_difference ["Consultation.count", "ProjectIntake.count"] do
      get workspace_url
    end
    assert_response :success
  end
end
