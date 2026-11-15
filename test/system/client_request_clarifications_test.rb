require "application_system_test_case"

class ClientRequestClarificationsSystemTest < ApplicationSystemTestCase
  PASSWORD = "fictional-client-reply-browser-password-2026".freeze

  setup do
    @prior_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    @owner = User.create!(email: "client-reply-browser-owner@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(
      email: "client-reply-browser@example.test", role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "fictional-browser-client-reply"
    )
    @intake = @client.client_project_intakes.create!(
      title: "Fictional mobile request reply", project_type: "website",
      goal: "A fictional website form requires testing on mobile screens.",
      demo_consent_at: Time.current
    )
    first = @intake.intake_messages.create!(role: "client", body: "Synthetic initial mobile requirement.")
    @intake.intake_messages.create!(role: "assistant", body: "A local sample acknowledgement.")
    OwnerIntakeInbox.mark_seen!(owner: @owner, intake: @intake, displayed_messages: [first])
  end

  teardown do
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @prior_pilot
  end

  test "client reply becomes unread for owner, then owner opens request and clears badge" do
    visit sign_in_path
    fill_in "Email address", with: @client.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path client_home_path

    visit client_request_path(@intake)
    assert_selector "#client-request-conversation li", count: 2
    assert_selector "textarea#reply_body[data-controller='wa-autogrow']"
    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
    fill_in "Your clarification", with: "Please test the fictional sign-up form with a keyboard."
    click_button "Send clarification"
    assert_current_path client_request_path(@intake)
    assert_selector "#intake-current .wa-context__latest-body",
      text: "Please test the fictional sign-up form with a keyboard."
    assert_selector ".wa-client-request__conversation .wa-context__history:not([open])", visible: :all
    find(".wa-client-request__conversation details.wa-context__history > summary").click
    assert_selector "#client-request-conversation li", count: 3
    fill_in "Search displayed history", with: "keyboard"
    assert_selector "#client-request-conversation li:not([hidden])", count: 1
    find("select[data-wa-intake-thread-target='order']").select("Newest first")
    assert_selector "#client-request-conversation li:not([hidden])", count: 1
    fill_in "Search displayed history", with: ""
    assert_selector "#client-request-conversation li:not([hidden])", count: 3
    assert_text "Please test the fictional sign-up form with a keyboard."

    visit client_home_path
    page.driver.browser.manage.window.resize_to(1400, 1400)
    click_button "Sign out"
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path
    assert_selector "header a.wa-inbox-nav .wa-unread-count", text: "1"

    visit admin_project_intakes_path
    assert_selector ".wa-inbox-record--unread", count: 1
    visit project_intake_path(@intake)
    assert_text "Please test the fictional sign-up form with a keyboard."
    assert_no_selector "header a.wa-inbox-nav .wa-unread-count"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
