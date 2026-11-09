require "test_helper"

class AccountAuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @previous_bootstrap = ENV["RC_LOCAL_OWNER_SIGNUP"]
    ENV["RC_LOCAL_OWNER_SIGNUP"] = "true"
    UserSession.delete_all
    User.delete_all
  end

  teardown do
    ENV["RC_LOCAL_OWNER_SIGNUP"] = @previous_bootstrap
  end

  test "first local owner can register and use protected pages" do
    get sign_up_path
    assert_response :success

    assert_difference "User.count", 1 do
      post sign_up_path, params: {
        user: { email: "  OWNER@example.test  ", password: "long-test-password-123",
                password_confirmation: "long-test-password-123" }
      }
    end
    assert_redirected_to consultations_path
    assert_equal "owner@example.test", User.last.email
    assert_not_equal "long-test-password-123", User.last.password_digest

    get new_consultation_path
    assert_response :success

    delete sign_out_path
    assert_redirected_to root_path
    assert_equal 0, UserSession.count
    get new_consultation_path
    assert_redirected_to admin_login_path
  end

  test "wrong password cannot sign in and second signup is closed" do
    post sign_up_path, params: {
      user: { email: "owner@example.test", password: "long-test-password-123",
              password_confirmation: "long-test-password-123" }
    }
    assert_redirected_to consultations_path
    get sign_up_path
    assert_response :not_found
    delete sign_out_path

    post account_session_path, params: { email: "owner@example.test", password: "incorrect-password" }
    assert_response :unauthorized
    get new_consultation_path
    assert_redirected_to admin_login_path

    post account_session_path, params: { email: "OWNER@EXAMPLE.TEST", password: "long-test-password-123" }
    assert_redirected_to consultations_path
    get new_consultation_path
    assert_response :success
  end

  test "registration is closed without explicit local flag" do
    ENV.delete("RC_LOCAL_OWNER_SIGNUP")
    get sign_up_path
    assert_response :not_found
    assert_no_difference "User.count" do
      post sign_up_path, params: {
        user: { email: "owner@example.test", password: "long-test-password-123",
                password_confirmation: "long-test-password-123" }
      }
    end
    assert_response :not_found
  end

  test "expired owner sessions cannot grant admin access" do
    post sign_up_path, params: {
      user: { email: "owner@example.test", password: "long-test-password-123",
              password_confirmation: "long-test-password-123" }
    }
    assert_redirected_to consultations_path

    travel 8.hours + 1.second do
      get new_consultation_path
      assert_redirected_to admin_login_path
    end
  end

  test "passwords shorter than twelve characters are rejected" do
    post sign_up_path, params: {
      user: { email: "owner@example.test", password: "short-pass",
              password_confirmation: "short-pass" }
    }
    assert_response :unprocessable_entity
    assert_equal 0, User.count
  end
end
