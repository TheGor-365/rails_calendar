require "test_helper"

# A single design system must cover every entry to the application.
# Routes/roles/CSRF are tested in their dedicated integration suites.
class AccountVisualConsistencyTest < ActionDispatch::IntegrationTest
  setup do
    @previous_flag = ENV["RC_CLIENT_SIGNUP_ENABLED"]
    ENV["RC_CLIENT_SIGNUP_ENABLED"] = "true"
  end

  teardown do
    ENV["RC_CLIENT_SIGNUP_ENABLED"] = @previous_flag
  end

  test "owner and client sign-in and signup share one layout and design assets" do
    get sign_in_url
    assert_response :success
    assert_select "body.app-shell.rc-account-shell", count: 1
    assert_select "header.rc-account-header nav.rc-account-nav", count: 1
    assert_select "section.rc-account-panel", count: 1
    assert_select "form[action=?]", account_session_path
    assert_select ".rc-account-nav-link[href=?]", client_registration_path
    assert_select ".rc-account-panel a.rc-account-option[href=?]", client_registration_path
    assert_select "link[href*='application']", minimum: 1
    assert_select ".rc-account-brand[href=?]", services_path

    get client_registration_url
    assert_response :success
    assert_select "body.app-shell.rc-account-shell", count: 1
    assert_select "header.rc-account-header nav.rc-account-nav", count: 1
    assert_select "section.rc-account-panel", count: 1
    assert_select "form[action=?]", client_registration_path
    assert_select "input[name='signup[consent]'][type=checkbox]", count: 1
    assert_select ".rc-account-panel a.rc-account-option[href=?]", sign_in_path
    assert_select "meta[name=robots][content='noindex,nofollow']"
  end

  test "legacy administrator login remains distinct but looks like the same application" do
    get admin_login_url
    assert_response :success
    assert_select "body.app-shell.rc-account-shell", count: 1
    assert_select "section.rc-account-panel form[action=?]", admin_session_path
    assert_select ".rc-account-brand[href=?]", services_path
  end

  test "verification and privacy remain consistent without exposing code" do
    post client_registration_url, params: { signup: {
      email: "visual-test-#{SecureRandom.hex(5)}@example.test",
      password: "long-visual-test-password-2026",
      password_confirmation: "long-visual-test-password-2026",
      consent: "1"
    } }
    assert_redirected_to verify_client_registration_url

    get verify_client_registration_url
    assert_response :success
    assert_select "body.app-shell.rc-account-shell", count: 1
    assert_select "form[action=?]", verify_client_registration_path
    assert_select "input[name=code][autocomplete=one-time-code]"
    # No plaintext code ever appears in the rendered response.
    assert_select "input[name=code][value]", count: 0

    get client_registration_privacy_url
    assert_response :success
    assert_select "body.app-shell.rc-account-shell", count: 1
    assert_select "meta[name=robots][content='noindex,nofollow']"
  end

  test "signup disabled by default does not expose registration" do
    ENV.delete("RC_CLIENT_SIGNUP_ENABLED")
    get client_registration_url
    assert_response :not_found
    get sign_in_url
    assert_response :success
    assert_select ".rc-account-nav-link[href=?]", client_registration_path, count: 0
  end
end
