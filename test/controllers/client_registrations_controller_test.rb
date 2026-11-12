require "test_helper"

class ClientRegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_flag = ENV["RC_CLIENT_SIGNUP_ENABLED"]
    ENV["RC_CLIENT_SIGNUP_ENABLED"] = "true"
    ActionMailer::Base.deliveries.clear
    ClientSignupChallenge.delete_all
    SignupRateWindow.delete_all
    UserSession.delete_all
    User.delete_all
  end

  teardown do
    ENV["RC_CLIENT_SIGNUP_ENABLED"] = @original_flag
    ActionMailer::Base.deliveries.clear
  end

  def signup(email: "client@example.test", password: "long-client-password-2026", consent: "1")
    post client_registration_path, params: {
      signup: {email: email, password: password,
               password_confirmation: password, consent: consent}
    }
  end

  def last_code
    ActionMailer::Base.deliveries.last.body.decoded.match(/\b\d{6}\b/).to_s
  end

  test "default-off flag denies all public signup actions while leaving privacy notice" do
    ENV.delete("RC_CLIENT_SIGNUP_ENABLED")
    get client_registration_path
    assert_response :not_found
    post client_registration_path, params: {signup: {email: "x@example.test", password: "password-password"}}
    assert_response :not_found
    get verify_client_registration_path
    assert_response :not_found
    get client_registration_privacy_path
    assert_response :success
  end

  test "verified email creates client only, with no access to owner workspace" do
    get client_registration_path
    assert_response :success
    assert_select "input[type=checkbox][name='signup[consent]']"
    assert_select "meta[name=robots][content='noindex,nofollow']"

    assert_difference "ClientSignupChallenge.count", 1 do
      assert_no_difference "User.count" do
        signup
      end
    end
    assert_redirected_to verify_client_registration_path
    challenge = ClientSignupChallenge.last
    refute_equal "long-client-password-2026", challenge.password_digest
    code = last_code
    assert_match(/\A\d{6}\z/, code)
    refute_equal code, challenge.code_digest
    assert_equal 1, ActionMailer::Base.deliveries.size

    assert_difference "User.count", 1 do
      post verify_client_registration_path, params: {code: code}
    end
    assert_redirected_to client_home_path
    user = User.last
    assert_equal "client", user.role
    assert user.verified_client?
    assert user.signup_consent_at.present?
    assert_equal 0, ClientSignupChallenge.count

    get client_home_path
    assert_response :success
    assert_select "h1", text: /Личный кабинет/
    assert_select "a[href='/workspace']", count: 0
    assert_select "a[href='/consultations']", count: 0
    get workspace_path
    assert_redirected_to sign_in_path
    get admin_project_intakes_path
    assert_redirected_to admin_login_path

    delete sign_out_path
    assert_redirected_to root_path
    get client_home_path
    assert_redirected_to sign_in_path

    post account_session_path, params: {email: user.email, password: "long-client-password-2026"}
    assert_redirected_to client_home_path
  end

  test "wrong, expired and repeated codes never activate clients" do
    signup
    good = last_code
    5.times do
      post verify_client_registration_path, params: {code: "ABCDEF"}
      assert_response :unprocessable_entity
    end
    assert_equal 5, ClientSignupChallenge.last.failed_attempts
    post verify_client_registration_path, params: {code: good}
    assert_response :unprocessable_entity
    assert_equal 0, User.count
  end

  test "expiration denies a correct code without a user" do
    signup
    good = last_code
    travel 11.minutes do
      post verify_client_registration_path, params: {code: good}
      assert_response :unprocessable_entity
    end
    assert_equal 0, User.count
  end

  test "resend rotates code after cooldown and invalidates earlier one" do
    signup
    old_code = last_code
    assert_equal 1, ActionMailer::Base.deliveries.length
    post resend_client_registration_path
    assert_redirected_to verify_client_registration_path
    assert_equal 1, ActionMailer::Base.deliveries.length

    travel 61.seconds do
      post resend_client_registration_path
      assert_redirected_to verify_client_registration_path
      assert_equal 2, ActionMailer::Base.deliveries.length
      new_code = last_code
      refute_equal old_code, new_code
      post verify_client_registration_path, params: {code: old_code}
      assert_response :unprocessable_entity
      post verify_client_registration_path, params: {code: new_code}
      assert_redirected_to client_home_path
    end
  end

  test "existing owner email is never overwritten or emailed a code" do
    owner = User.create!(email: "existing@example.test", role: "owner",
                         password: "long-owner-password-2026")
    signup(email: "existing@example.test")
    assert_redirected_to verify_client_registration_path
    assert_equal 0, ClientSignupChallenge.count
    assert_equal 0, ActionMailer::Base.deliveries.length
    assert_equal "owner", owner.reload.role
  end

  test "consent, email and password validation prevent premature persistence" do
    signup(consent: "0")
    assert_response :unprocessable_entity
    assert_equal 0, ClientSignupChallenge.count
    signup(email: "not-an-email")
    assert_response :unprocessable_entity
    signup(password: "short")
    assert_response :unprocessable_entity
    assert_equal 0, User.count
  end

  test "database-backed IP limit prevents mass email sends" do
    5.times do |i|
      signup(email: "client#{i}@example.test")
      assert_redirected_to verify_client_registration_path
    end
    assert_equal 5, ActionMailer::Base.deliveries.length
    signup(email: "client6@example.test")
    assert_response :too_many_requests
    assert_equal 5, ActionMailer::Base.deliveries.length
  end

  test "client home is not a public surface" do
    get client_home_path
    assert_redirected_to sign_in_path
  end
end
