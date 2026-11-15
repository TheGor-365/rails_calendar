require "test_helper"

class RequestSideNavigationTest < ActionDispatch::IntegrationTest
  PASSWORD = "fictional-sticky-rail-controller-password-2026".freeze

  setup do
    @previous_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    AdminLoginWindow.delete_all
    @owner = User.create!(email: "side-nav-controller-owner@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(
      email: "side-nav-controller-client@example.test", role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "fictional-side-nav"
    )
    @intake = @client.client_project_intakes.create!(
      title: "Fictional test navigation", project_type: "website",
      goal: "Fictional site", demo_consent_at: Time.current
    )
    @intake.intake_messages.create!(role: "client", body: "Fictional brief")
    @intake.intake_messages.create!(role: "assistant", body: "Fictional acknowledgement")
  end

  teardown do
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @previous_pilot
  end

  test "one owner navigation landmark has section ids and no unpublished-spec link" do
    post account_session_path, params: { email: @owner.email, password: PASSWORD }
    assert_redirected_to workspace_path
    get project_intake_path(@intake)
    assert_response :success
    assert_select "aside.wa-detail-shell__aside nav.wa-detail-shell__links", count: 1
    assert_select "aside.wa-detail-shell__aside nav a[href='#intake-current']"
    assert_select "aside.wa-detail-shell__aside nav a[href='#intake-review']"
    assert_select "aside.wa-detail-shell__aside nav a[href='#intake-spec']", count: 0
    assert_select "nav.wa-owner-intake__jump", count: 0
  end

  test "client gets only permitted nav targets, with locale labels across four languages" do
    post account_session_path, params: { email: @client.email, password: PASSWORD }
    assert_redirected_to client_home_path
    get client_request_path(@intake)
    assert_response :success
    assert_select "aside.wa-detail-shell__aside nav.wa-detail-shell__links", count: 1
    assert_select "aside.wa-detail-shell__aside nav a[href='#client-request-reply']", count: 1
    assert_select "aside.wa-detail-shell__aside nav a[href='#intake-review']", count: 0

    %i[ru en hy es].each do |locale|
      I18n.with_locale(locale) do
        assert I18n.exists?("intake_context.side_nav_title")
        assert I18n.exists?("intake_context.side_nav_help")
        assert I18n.exists?("intake_context.side_nav_note")
      end
    end
  end
end
