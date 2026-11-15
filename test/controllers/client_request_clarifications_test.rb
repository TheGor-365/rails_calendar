require "test_helper"

class ClientRequestClarificationsTest < ActionDispatch::IntegrationTest
  PASSWORD = "fictional-client-followup-test-password-2026".freeze

  setup do
    @prior_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    @prior_ai = ENV["RC_GROK_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    ENV["RC_GROK_ENABLED"] = "false"

    @owner = User.create!(email: "followup-owner@example.test", role: "owner", password: PASSWORD)
    @client = verified_client("followup-client@example.test")
    @other_client = verified_client("followup-other@example.test")
    @intake = @client.client_project_intakes.create!(
      title: "Fictional accessibility test", project_type: "website",
      goal: "A fictional site needs a synthetic form and accessibility check.",
      demo_consent_at: Time.current
    )
    @first = @intake.intake_messages.create!(role: "client", body: @intake.goal)
    @intake.intake_messages.create!(role: "assistant", body: "Local pilot acknowledgement.")
  end

  teardown do
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @prior_pilot
    ENV["RC_GROK_ENABLED"] = @prior_ai
  end

  test "verified client's form creates one unread clarification, leaving spec state and AI untouched" do
    OwnerIntakeInbox.mark_seen!(owner: @owner, intake: @intake, displayed_messages: [@first])
    assert_equal 0, OwnerIntakeInbox.unread_for(owner: @owner).count
    sign_in(@client)

    get client_request_path(@intake)
    assert_response :success
    assert_select "#client-request-conversation li", count: 2
    assert_select "form#client-reply-form[action=?]", reply_client_request_path(@intake), count: 1
    assert_select "form#client-reply-form input[name='submission_key'][value]", count: 1
    assert_select "form#client-reply-form textarea[name='reply_body'][maxlength='1200'][data-controller='wa-autogrow']", count: 1
    token = "a" * 32
    text = "Fictional clarification: please test the form on narrow screens."

    assert_difference("IntakeMessage.count", 1) do
      post reply_client_request_path(@intake), params: { submission_key: token, reply_body: text }
    end
    assert_redirected_to client_request_path(@intake)
    newest = @intake.intake_messages.order(:id).last
    assert_equal "client", newest.role
    assert_equal text, newest.body
    assert_equal token, newest.client_submission_key
    assert_equal 1, OwnerIntakeInbox.unread_for(owner: @owner).count
    assert_equal @first.id, OwnerIntakeReadState.find_by!(owner_user: @owner, project_intake: @intake).last_seen_client_message_id
    assert_equal "interviewing", @intake.reload.status
    assert_nil @intake.latest_spec
    assert_equal 0, IntakeAiQuota.count

    get client_request_path(@intake)
    assert_response :success
    assert_select "#client-request-conversation li", count: 3
    assert_select ".wa-client-request__message--client", text: /narrow screens/, count: 1
    delete sign_out_path

    sign_in(@owner)
    get admin_project_intakes_path
    assert_select ".wa-inbox-record--unread", count: 1
    assert_select "header a.wa-inbox-nav .wa-unread-count", text: "1"
    get project_intake_path(@intake)
    assert_response :success
    assert_select "#intake-conversation li[data-wa-intake-thread-role='client']", count: 2
    assert_equal 0, OwnerIntakeInbox.unread_for(owner: @owner).count
  end

  test "same submission key is idempotent with different body and even at the cap" do
    sign_in(@client)
    token = "b" * 32
    post reply_client_request_path(@intake), params: { submission_key: token, reply_body: "Original fictional clarification" }
    assert_response :see_other

    assert_no_difference("IntakeMessage.count") do
      post reply_client_request_path(@intake), params: { submission_key: token, reply_body: "Changed body must not override" }
    end
    assert_response :see_other
    assert_equal "Original fictional clarification",
      @intake.intake_messages.find_by!(client_submission_key: token).body

    6.times do |n|
      post reply_client_request_path(@intake), params: {
        submission_key: (n + 1).to_s.rjust(32, "c"), reply_body: "Fictional extra message #{n}"
      }
      assert_response :see_other
    end
    assert_equal ProjectIntake::MAX_CLIENT_MESSAGES, @intake.client_message_count

    assert_no_difference("IntakeMessage.count") do
      post reply_client_request_path(@intake), params: {
        submission_key: token, reply_body: "Duplicate still idempotent at maximum"
      }
    end
    assert_response :see_other
    assert_no_difference("IntakeMessage.count") do
      post reply_client_request_path(@intake), params: {
        submission_key: "d" * 32, reply_body: "New one above the pilot cap"
      }
    end
    assert_response :unprocessable_entity
    assert_select ".wa-client-request__reply-closed"
    assert_select "#client-reply-form", count: 0
  end

  test "client validation rejects missing or overlong content, invalid token, and preserves safe input" do
    sign_in(@client)
    valid = "e" * 32
    [ ["", valid], [" " * 6, valid], ["Z" * 1201, valid], ["Synthetic valid text", "invalid"] ].each do |body, token|
      assert_no_difference("IntakeMessage.count") do
        post reply_client_request_path(@intake), params: { submission_key: token, reply_body: body }
      end
      assert_response :unprocessable_entity
      assert_select "[role='alert']"
      assert_select "#client-reply-form", count: 1
    end
    assert_equal 1, @intake.client_message_count
  end

  test "cross-client, owner, and disabled pilot cannot post to another account's request" do
    sign_in(@other_client)
    assert_no_difference("IntakeMessage.count") do
      post reply_client_request_path(@intake), params: { submission_key: "f" * 32, reply_body: "Not my request" }
    end
    assert_response :not_found
    delete sign_out_path

    sign_in(@owner)
    assert_no_difference("IntakeMessage.count") do
      post reply_client_request_path(@intake), params: { submission_key: "f" * 32, reply_body: "Owner is not client" }
    end
    assert_redirected_to sign_in_path
    delete sign_out_path

    sign_in(@client)
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "false"
    assert_no_difference("IntakeMessage.count") do
      post reply_client_request_path(@intake), params: { submission_key: "f" * 32, reply_body: "Disabled pilot" }
    end
    assert_response :not_found
  end

  test "malicious html remains escaped and reply never edits approved owner specification" do
    sign_in(@client)
    @intake.update!(status: "draft_spec")
    text = "<script>alert('synthetic')</script>\nA safe fictional detail."
    post reply_client_request_path(@intake), params: { submission_key: "a" * 32, reply_body: text }
    assert_response :see_other
    assert_equal "draft_spec", @intake.reload.status

    get client_request_path(@intake)
    assert_response :success
    assert_includes response.body, "&lt;script&gt;"
    assert_select "script", text: /alert\('synthetic'\)/, count: 0
    assert_select ".wa-client-request__message--client", text: /safe fictional detail/i, count: 1
  end

  test "all four locales include client reply UI labels" do
    %i[en ru hy es].each do |locale|
      I18n.with_locale(locale) do
        %w[conversation_title conversation_help message_client message_assistant reply_title reply_help
           reply_label reply_placeholder reply_send reply_saved reply_duplicate reply_invalid_request
           reply_required reply_too_long reply_limit].each do |key|
          assert I18n.exists?("client_requests.#{key}"), "Missing #{locale}.client_requests.#{key}"
          assert_not_match(/Translation missing/i, I18n.t("client_requests.#{key}", remaining: 4).to_s)
        end
      end
    end
  end

  private

  def verified_client(email)
    User.create!(
      email: email, role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "synthetic-client-followup"
    )
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end
end
