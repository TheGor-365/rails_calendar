require "test_helper"

class ClientRequestsPilotTest < ActionDispatch::IntegrationTest
  PASSWORD = "safe-synthetic-test-password-2026".freeze

  setup do
    @prior_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    @prior_ai = ENV["RC_GROK_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    ENV["RC_GROK_ENABLED"] = "false"
    @owner = User.create!(email: "pilot-owner@example.test", password: PASSWORD, role: "owner")
    @client_a = User.create!(email: "pilot-client-a@example.test", password: PASSWORD,
      role: "client", email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "pilot-test")
    @client_b = User.create!(email: "pilot-client-b@example.test", password: PASSWORD,
      role: "client", email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "pilot-test")
  end

  teardown do
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @prior_pilot
    ENV["RC_GROK_ENABLED"] = @prior_ai
  end

  def sign_in_as(user)
    post account_session_path, params: {email: user.email, password: PASSWORD}
    assert_redirected_to(user.role == "owner" ? workspace_path : client_home_path)
  end

  def create_fictional_request
    post client_requests_path, params: {
      project_intake: {
        title: "Synthetic bakery site",
        project_type: "website",
        goal: "A fictional bakery needs a website with an enquiry form.",
        client_user_id: @client_b.id
      }, demo_consent: "1"
    }
    assert_response :redirect
    ProjectIntake.order(:id).last
  end

  test "verified client submits to owner; approved revision is shared only with its owner" do
    sign_in_as(@client_a)
    get new_client_request_path
    assert_response :success
    assert_select "form[action=?]", client_requests_path
    assert_difference ["ProjectIntake.count", "IntakeMessage.count"], [1, 2] do
      @intake = create_fictional_request
    end
    assert_equal @client_a.id, @intake.client_user_id
    assert_equal "interviewing", @intake.status
    assert_equal 1, @intake.client_message_count
    assert_redirected_to client_request_path(@intake)

    get client_home_path
    assert_response :success
    assert_select "a[href=?]", client_request_path(@intake)
    get client_request_path(@intake)
    assert_response :success
    assert_select "h1", text: @intake.title
    assert_select "#client-request-spec", text: /Owner-reviewed specification/

    # Existing owner-only paths do not acquire client access by sharing an ID.
    get project_intake_path(@intake)
    assert_response :not_found
    get project_intake_quiz_path(@intake)
    assert_redirected_to sign_in_path
    get admin_project_intakes_path
    assert_redirected_to admin_login_path
    delete sign_out_path

    sign_in_as(@client_b)
    get client_home_path
    assert_response :success
    assert_select "a[href=?]", client_request_path(@intake), count: 0
    get client_request_path(@intake)
    assert_response :not_found
    post review_client_request_path(@intake), params: {version: "1"}
    assert_response :not_found
    delete sign_out_path

    sign_in_as(@owner)
    get admin_project_intakes_path
    assert_response :success
    assert_select "a[href=?]", project_intake_path(@intake), count: 1
    get project_intake_path(@intake)
    assert_response :success
    post draft_spec_admin_project_intake_path(@intake)
    assert_response :redirect
    draft = @intake.reload.latest_spec
    assert_equal "template", draft.source
    refute draft.approved?
    post approve_spec_admin_project_intake_path(@intake)
    assert_response :redirect
    assert @intake.reload.published_spec.approved?
    delete sign_out_path

    sign_in_as(@client_a)
    get client_request_path(@intake)
    assert_response :success
    assert_select "form[action=?]", review_client_request_path(@intake)
    assert_select "h2#client-request-spec"
    assert_select "h3", text: "Acceptance criteria"
    post review_client_request_path(@intake), params: {version: draft.version + 1}
    assert_response :conflict
    assert_nil draft.reload.client_reviewed_at
    post review_client_request_path(@intake), params: {version: draft.version}
    assert_redirected_to client_request_path(@intake)
    assert draft.reload.client_reviewed_at.present?
    assert_equal "client_reviewed", @intake.reload.status
    assert_equal 0, IntakeAiQuota.count
  end

  test "client request rejects missing consent, overlong content and cross-user assignment" do
    sign_in_as(@client_a)
    assert_no_difference "ProjectIntake.count" do
      post client_requests_path, params: {project_intake: {
        title: "Synthetic", goal: "Synthetic sample customer goal",
        project_type: "website"
      }}
    end
    assert_response :unprocessable_entity

    assert_no_difference "ProjectIntake.count" do
      post client_requests_path, params: {demo_consent: "1", project_intake: {
        title: "Synthetic", goal: "X" * 1201, project_type: "website"
      }}
    end
    assert_response :unprocessable_entity

    intake = create_fictional_request
    assert_equal @client_a.id, intake.client_user_id
    refute_equal @client_b.id, intake.client_user_id
  end

  test "local flag disabled denies all pilot routes and keeps verified client isolated" do
    sign_in_as(@client_a)
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "false"
    get client_home_path
    assert_response :success
    assert_select "a[href=?]", new_client_request_path, count: 0
    assert_no_difference "ProjectIntake.count" do
      post client_requests_path, params: {project_intake: {
        title: "Synthetic", project_type: "website",
        goal: "Some entirely synthetic example goal"
      }, demo_consent: "1"}
      assert_response :not_found
    end
    get new_client_request_path
    assert_response :not_found
  end

  test "all four locales keep canonical type and accessible client request form" do
    sign_in_as(@client_a)
    %w[en ru hy es].each do |locale|
      post language_path, params: {locale: locale, return_to: new_client_request_path}
      assert_response :see_other
      get new_client_request_path
      assert_response :success
      assert_select "html[lang=?]", locale
      assert_select "h1", text: I18n.t("client_requests.new_title", locale: locale)
      assert_select "option[value=rails_bugfix]", count: 1
      assert_select "input[type=checkbox][name=demo_consent]", count: 1
    end
  end
end
