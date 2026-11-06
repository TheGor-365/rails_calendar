require "test_helper"

class AdminSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Admin::SessionsController::LOGIN_RATE_LIMIT_STORE.clear
  end
  test "login limits the sixth request and keeps anonymous calendar public" do
    5.times do
      post admin_session_url, params: {
        username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
        password: "invalid-test-password"
      }
      assert_response :unauthorized
    end

    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_response :too_many_requests

    get consultations_url
    assert_response :success
    get new_consultation_url
    assert_redirected_to admin_login_url
  end

  test "administrator login page is public" do
    get admin_login_url
    assert_response :success
    assert_select "form[action=?]", admin_session_path
  end

  test "wrong password cannot start a session" do
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: "wrong-password"
    }
    assert_response :unauthorized

    get new_consultation_url
    assert_redirected_to admin_login_url
  end

  test "correct credentials permit access until logout" do
    sign_in

    get new_consultation_url
    assert_response :success

    delete admin_logout_url
    assert_redirected_to root_url

    get new_consultation_url
    assert_redirected_to admin_login_url
  end

  test "logout revokes all write routes while public calendar remains available" do
    sign_in
    record = consultations(:one)
    original_title = record.title

    delete admin_logout_url
    assert_redirected_to root_url

    assert_no_difference "Consultation.count" do
      post consultations_url, params: {
        consultation: {
          title: "Unauthorized after logout",
          start_time: "2026-11-12T09:00",
          end_time: "2026-11-12T09:30"
        }
      }
    end
    assert_redirected_to admin_login_url

    patch consultation_url(record), params: { consultation: { title: "Unauthorized after logout" } }
    assert_redirected_to admin_login_url
    assert_equal original_title, record.reload.title

    assert_no_difference "Consultation.count" do
      delete consultation_url(record)
    end
    assert_redirected_to admin_login_url

    get calendar_day_url(date: "2026-11-12")
    assert_response :success
    get consultations_url
    assert_response :success
  end

  test "expired cookie cannot update or delete a record" do
    sign_in
    record = consultations(:one)
    original_title = record.title

    travel 8.hours + 1.second do
      patch consultation_url(record), params: { consultation: { title: "Unauthorized expired update" } }
      assert_redirected_to admin_login_url
      assert_equal original_title, record.reload.title

      assert_no_difference "Consultation.count" do
        delete consultation_url(record)
      end
      assert_redirected_to admin_login_url
    end
  end

  test "expired session is not accepted" do
    sign_in
    travel 8.hours + 1.second do
      get edit_consultation_url(consultations(:one))
      assert_redirected_to admin_login_url
    end
  end

  test "rotating the password invalidates existing admin sessions" do
    sign_in
    previous = ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    begin
      ENV["RAILS_CALENDAR_ADMIN_PASSWORD"] = "rotated-test-only-password"
      get new_consultation_url
      assert_redirected_to admin_login_url
    ensure
      ENV["RAILS_CALENDAR_ADMIN_PASSWORD"] = previous
    end
  end

  test "missing server secrets fail closed" do
    previous_username = ENV["RAILS_CALENDAR_ADMIN_USERNAME"]
    previous_password = ENV["RAILS_CALENDAR_ADMIN_PASSWORD"]
    begin
      ENV.delete("RAILS_CALENDAR_ADMIN_USERNAME")
      ENV.delete("RAILS_CALENDAR_ADMIN_PASSWORD")
      post admin_session_url, params: { username: "test-admin", password: "something" }
      assert_response :unauthorized
      get new_consultation_url
      assert_redirected_to admin_login_url
    ensure
      ENV["RAILS_CALENDAR_ADMIN_USERNAME"] = previous_username
      ENV["RAILS_CALENDAR_ADMIN_PASSWORD"] = previous_password
    end
  end

  private

  def sign_in
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_redirected_to consultations_url
  end
end
