require "test_helper"

class AccountCabinetsTest < ActionDispatch::IntegrationTest
  PASSWORD = "private-cabinet-test-password-2026"

  setup do
    @owner = User.create!(email: "cabinet-owner@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(email: "cabinet-client@example.test", role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "cabinet-test")
  end

  def login_as(user)
    post account_session_path, params: {email: user.email, password: PASSWORD}
    assert_redirected_to(user.role == "owner" ? workspace_path : client_home_path)
  end

  test "owner cabinet creates only scoped empty profile and links to actual tools" do
    login_as(@owner)
    assert_difference({"Workspace.count" => 1, "ProfessionalProfile.count" => 1}) do
      get owner_cabinet_path
    end
    assert_response :success
    assert_select "#owner-cabinet h1", text: I18n.t("account_hub.owner_title")
    assert_select ".ws-account-tool[href=?]", owner_setup_path(step: "A")
    assert_select ".ws-account-tool[href=?]", owner_practice_path
    assert_select ".ws-account-tool[href=?]", owner_ai_activity_path
    assert_select ".ws-account-tool[href=?]", workspace_path
    assert_select "a[href=?]", owner_cabinet_path
    assert_no_match(/cabinet-client@example.test/, response.body)
    get workspace_path
    assert_response :success
    assert_select "a[href=?]", owner_setup_path
  end

  test "client cabinet remains private and shows verified identity without owner context" do
    login_as(@client)
    get client_cabinet_path
    assert_response :success
    assert_select "#client-cabinet h1", text: I18n.t("account_hub.client_title")
    assert_select ".ws-client-panel h2", text: I18n.t("client.panel_title")
    assert_select ".ws-client-heading .rc-muted", text: I18n.t("client.description")
    assert_select "a[href=?]", client_cabinet_path
    assert_no_match(/cabinet-owner@example.test/, response.body)
    assert_equal 0, Workspace.count
    assert_equal 0, ProfessionalProfile.count
  end

  test "role separation: neither guests nor clients can read owner cabinet and owner cannot read client cabinet" do
    get owner_cabinet_path
    assert_redirected_to sign_in_path
    get client_cabinet_path
    assert_redirected_to sign_in_path

    login_as(@client)
    get owner_cabinet_path
    assert_redirected_to sign_in_path
    assert_equal 0, Workspace.count
    delete sign_out_path

    login_as(@owner)
    get client_cabinet_path
    assert_redirected_to sign_in_path
    get owner_cabinet_path
    assert_response :success
    get services_path
    assert_response :success
    assert_select "#owner-cabinet", count: 0
    assert_select "#owner-practice", count: 0
  end

  test "cabinets respect selected Russian UI locale without changing global calendar" do
    login_as(@owner)
    post language_path, params: {locale: "ru", return_to: owner_cabinet_path}
    assert_response :see_other
    get owner_cabinet_path
    assert_response :success
    assert_select "html[lang=ru]"
    assert_select "#owner-cabinet h1", text: "Мой кабинет"
    get root_path
    assert_response :success
  end
end
