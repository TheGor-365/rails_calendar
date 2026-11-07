require "test_helper"

# These assertions exercise the real HTTP route and session cookies rather
# than calling the rate-limit model directly. All records are test fixtures.
class AdminSecurityHttpGateTest < ActionDispatch::IntegrationTest
  setup { AdminLoginWindow.delete_all }

  test "HTTP login rejects sixth submission before processing valid credentials" do
    5.times do
      post admin_session_url, params: {
        username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
        password: "intentionally-incorrect"
      }
      assert_response :unauthorized
    end

    assert_equal 1, AdminLoginWindow.count
    assert_equal 5, AdminLoginWindow.first.attempts

    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_response :too_many_requests
    assert_equal 6, AdminLoginWindow.first.attempts

    # No admin cookie may be minted on the blocked sixth request.
    get new_consultation_url
    assert_redirected_to admin_login_url
  end

  test "a successful login still counts and signing out revokes edit access" do
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_redirected_to consultations_url
    assert_equal 1, AdminLoginWindow.first.attempts

    get edit_consultation_url(consultations(:one))
    assert_response :success
    delete admin_logout_url
    assert_redirected_to root_url
    get edit_consultation_url(consultations(:one))
    assert_redirected_to admin_login_url
  end

  test "database outage fails closed with HTTP 503 and no session" do
    # Minitest 6 no longer ships minitest/mock; replace the singleton method
    # temporarily and restore it in ensure, without extra gems or DB outages.
    original_method = AdminLoginWindow.method(:throttled?)
    begin
      AdminLoginWindow.define_singleton_method(:throttled?) do |remote_ip:|
        raise ActiveRecord::ConnectionNotEstablished, "test-only simulated outage"
      end

      post admin_session_url, params: {
        username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
        password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
      }
      assert_response :service_unavailable
    ensure
      AdminLoginWindow.define_singleton_method(:throttled?, original_method)
    end

    get edit_consultation_url(consultations(:one))
    assert_redirected_to admin_login_url
  end

  test "only admin mutation requests change records after a successful login" do
    consultation = consultations(:one)
    before_title = consultation.title

    patch consultation_url(consultation), params: {
      consultation: { title: "Unapproved edit" }
    }
    assert_redirected_to admin_login_url
    assert_equal before_title, consultation.reload.title

    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_redirected_to consultations_url
    patch consultation_url(consultation), params: {
      consultation: { lock_version: consultation.lock_version, title: "Approved edit (isolated fixture)" }
    }
    assert_redirected_to consultation_url(consultation)
    assert_equal "Approved edit (isolated fixture)", consultation.reload.title
  end
end
