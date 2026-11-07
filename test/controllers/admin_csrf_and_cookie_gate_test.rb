require "test_helper"

# This suite deliberately enables the real Rails forgery verifier, which the
# regular test environment disables for fixtures and request convenience.
# It must never use an owner's development or production database.
class AdminCsrfAndCookieGateTest < ActionDispatch::IntegrationTest
  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    @previous_origin_check = ActionController::Base.forgery_protection_origin_check
    ActionController::Base.allow_forgery_protection = true
    ActionController::Base.forgery_protection_origin_check = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    ActionController::Base.forgery_protection_origin_check = @previous_origin_check
  end

  test "login form renders a session-bound CSRF token" do
    get admin_login_url
    assert_response :success
    assert_select "meta[name='csrf-token'][content]", count: 1
    assert_select "form[action=?] input[name='authenticity_token'][value]", admin_session_path, count: 1
  end

  test "login POST without CSRF token is rejected before minting admin session" do
    get admin_login_url
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post admin_session_url, params: credentials
    end

    get new_consultation_url
    assert_redirected_to admin_login_url
  end

  test "valid login token works on same origin and foreign origin is refused" do
    get admin_login_url
    token = login_form_token

    assert_raises(ActionController::InvalidAuthenticityToken) do
      post admin_session_url,
           params: credentials.merge(authenticity_token: token),
           headers: { "Origin" => "https://untrusted.example.invalid" }
    end
    get new_consultation_url
    assert_redirected_to admin_login_url

    # The invalid request may reset the CSRF session token. Reload the form.
    get admin_login_url
    token = login_form_token
    post admin_session_url,
         params: credentials.merge(authenticity_token: token),
         headers: { "Origin" => "http://www.example.com" }
    assert_redirected_to consultations_url
    get new_consultation_url
    assert_response :success
  end

  test "authenticated mutation and logout reject invalid CSRF tokens" do
    get admin_login_url
    post admin_session_url, params: credentials.merge(authenticity_token: login_form_token)
    assert_redirected_to consultations_url

    record = consultations(:two)
    old_title = record.title
    get edit_consultation_url(record)
    assert_response :success
    token = response.parsed_body.at_css("form input[name='authenticity_token']")&.[]("value")
    assert token.present?, "edit form must include a CSRF token"

    assert_raises(ActionController::InvalidAuthenticityToken) do
      patch consultation_url(record), params: {
        consultation: { title: "Invalid CSRF update", lock_version: record.lock_version }
      }
    end
    assert_equal old_title, record.reload.title

    assert_raises(ActionController::InvalidAuthenticityToken) do
      patch consultation_url(record),
            params: {
              authenticity_token: token,
              consultation: { title: "Cross-origin update", lock_version: record.lock_version }
            },
            headers: { "Origin" => "https://untrusted.example.invalid" }
    end
    assert_equal old_title, record.reload.title

    assert_raises(ActionController::InvalidAuthenticityToken) do
      delete admin_logout_url
    end
    get edit_consultation_url(record)
    assert_response :success
  end

  test "session cookie sets host-only HttpOnly and Lax options" do
    options = Rails.application.config.session_options
    assert_equal "_rails_calendar_session", options[:key]
    assert_equal "/", options[:path]
    assert_equal true, options[:httponly]
    assert_equal :lax, options[:same_site]
    assert_equal false, options[:secure], "test mode must not claim production TLS"
    assert_nil options[:domain], "session cookie must stay host-only"

    get admin_login_url
    post admin_session_url, params: credentials.merge(authenticity_token: login_form_token)
    assert_redirected_to consultations_url
    header = response.headers["Set-Cookie"].to_s
    assert_includes header, "_rails_calendar_session="
    assert_match(/httponly/i, header)
    assert_match(/samesite=lax/i, header)
  end

  private

  def credentials
    {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
  end

  def login_form_token
    token = response.parsed_body.at_css("form input[name='authenticity_token']")&.[]("value")
    assert token.present?, "login form must include a CSRF token"
    token
  end
end
