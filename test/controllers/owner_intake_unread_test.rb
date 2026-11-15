require "test_helper"

class OwnerIntakeUnreadTest < ActionDispatch::IntegrationTest
  PASSWORD = "local-unread-pilot-test-password-2026".freeze

  setup do
    @old_local_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"

    @owner = User.create!(email: "unread-owner@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(
      email: "unread-client@example.test", role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "unread-pilot-test"
    )
    @request_a = new_client_intake("Synthetic first request")
    @request_b = new_client_intake("Synthetic second request")
    @a_first = @request_a.intake_messages.create!(role: "client", body: "Synthetic initial request A")
    @request_a.intake_messages.create!(role: "assistant", body: "Synthetic template acknowledgement A")
    @b_first = @request_b.intake_messages.create!(role: "client", body: "Synthetic initial request B")
    @request_b.intake_messages.create!(role: "assistant", body: "Synthetic template acknowledgement B")
  end

  teardown do
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @old_local_pilot
  end

  test "owner inbox counts unique unread client requests; index never consumes read receipts" do
    sign_in(@owner)
    assert_equal 2, OwnerIntakeInbox.unread_for(owner: @owner).count

    get workspace_path
    assert_response :success
    assert_select "header.app-header a.wa-inbox-nav[href=?] .wa-unread-count", admin_project_intakes_path, text: "2"
    assert_select "nav.rc-mobile-dock--owner a.wa-inbox-mobile[href=?] .wa-unread-count", admin_project_intakes_path, text: "2"

    get admin_project_intakes_path
    assert_response :success
    assert_select ".wa-inbox-record--unread", count: 2
    assert_select ".wa-inbox-record__new", text: "New", count: 2
    assert_equal 0, OwnerIntakeReadState.count, "inbox list view must not mark any request as read"

    get project_intake_path(@request_a)
    assert_response :success
    receipt = OwnerIntakeReadState.find_by!(owner_user: @owner, project_intake: @request_a)
    assert_equal @a_first.id, receipt.last_seen_client_message_id
    assert_equal 1, OwnerIntakeInbox.unread_for(owner: @owner).count
    assert_select "header.app-header a.wa-inbox-nav .wa-unread-count", text: "1"

    get admin_project_intakes_path
    assert_response :success
    assert_select ".wa-inbox-record--unread", count: 1
    assert_equal 1, OwnerIntakeReadState.count

    get project_intake_path(@request_b)
    assert_response :success
    assert_equal @b_first.id,
      OwnerIntakeReadState.find_by!(owner_user: @owner, project_intake: @request_b).last_seen_client_message_id
    assert_equal 0, OwnerIntakeInbox.unread_for(owner: @owner).count
    assert_select "header.app-header a.wa-inbox-nav .wa-unread-count", count: 0
    assert_select "nav.rc-mobile-dock--owner a.wa-inbox-mobile .wa-unread-count", count: 0
  end

  test "a newer client message restores the unread badge and stale tabs cannot rewind a cursor" do
    OwnerIntakeInbox.mark_seen!(owner: @owner, intake: @request_a, displayed_messages: [@a_first])
    newer = @request_a.intake_messages.create!(role: "client", body: "Synthetic clarification after prior read")
    assert_includes OwnerIntakeInbox.unread_for(owner: @owner).pluck(:id), @request_a.id

    OwnerIntakeInbox.mark_seen!(owner: @owner, intake: @request_a, displayed_messages: [@a_first])
    assert_equal @a_first.id,
      OwnerIntakeReadState.find_by!(owner_user: @owner, project_intake: @request_a).last_seen_client_message_id

    OwnerIntakeInbox.mark_seen!(owner: @owner, intake: @request_a,
                               displayed_messages: [@a_first, newer])
    refute_includes OwnerIntakeInbox.unread_for(owner: @owner).pluck(:id), @request_a.id

    OwnerIntakeInbox.mark_seen!(owner: @owner, intake: @request_a, displayed_messages: [@a_first])
    record = OwnerIntakeReadState.find_by!(owner_user: @owner, project_intake: @request_a)
    assert_equal newer.id, record.last_seen_client_message_id, "stale page must not move seen cursor backward"
    assert_equal 1, OwnerIntakeReadState.where(project_intake: @request_a, owner_user: @owner).count

    other = @request_b.intake_messages.create!(role: "client", body: "Different request: no cross-intake cursor")
    invalid = OwnerIntakeReadState.new(
      owner_user: @owner, project_intake: @request_a,
      last_seen_client_message: other, first_seen_at: Time.current, last_seen_at: Time.current
    )
    assert_not invalid.valid?
  end

  test "client and legacy administrator never consume the owner's read receipt" do
    sign_in(@client)
    assert_equal 0, OwnerIntakeInbox.unread_for(owner: @client).count

    get client_request_path(@request_a)
    assert_response :success
    get admin_project_intakes_path
    assert_redirected_to admin_login_path
    get project_intake_path(@request_a)
    assert_response :not_found
    assert_equal 0, OwnerIntakeReadState.count

    delete sign_out_path
    post admin_session_path, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    get admin_project_intakes_path
    assert_response :success
    assert_select ".wa-inbox-record--unread", count: 0
    assert_select "header.app-header .wa-unread-count", count: 0
    get project_intake_path(@request_a)
    assert_response :success
    assert_equal 0, OwnerIntakeReadState.count
  end

  test "owner-only synthetic intakes and assistant messages never generate false unread badges" do
    owner_created = ProjectIntake.create!(
      title: "Owner synthetic training", project_type: "rails_bugfix",
      goal: "Owner created a fictional task without a verified client.",
      demo_consent_at: Time.current
    )
    owner_created.intake_messages.create!(role: "client", body: "Legacy demo input")
    @request_b.intake_messages.create!(role: "assistant", body: "No client reply")
    assert_equal 2, OwnerIntakeInbox.unread_for(owner: @owner).count
    refute_includes OwnerIntakeInbox.unread_for(owner: @owner).pluck(:id), owner_created.id

    assert_not OwnerIntakeInbox.mark_seen!(owner: @owner, intake: owner_created,
                                          displayed_messages: owner_created.intake_messages.to_a)
    assert_equal 0, OwnerIntakeReadState.count
  end

  test "unread indicator labels exist in each locale" do
    %i[en ru hy es].each do |locale|
      I18n.with_locale(locale) do
        assert I18n.exists?("intake.unread_count")
        assert I18n.exists?("intake.unread_new")
        refute_match(/Translation missing/, I18n.t("intake.unread_count", count: 2))
      end
    end
  end

  private

  def new_client_intake(title)
    @client.client_project_intakes.create!(
      title: title, project_type: "website",
      goal: "A fictional customer is asking for a synthetic website.",
      demo_consent_at: Time.current
    )
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "owner" ? workspace_path : client_home_path)
  end
end
