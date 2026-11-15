require "application_system_test_case"

class CurrentContextOwnerUnreadSystemTest < ApplicationSystemTestCase
  PASSWORD = "fictional-current-context-owner-password-2026".freeze

  setup do
    AdminLoginWindow.delete_all
    @owner = User.create!(email: "current-record-owner@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(
      email: "current-record-client@example.test", role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "fictional-current-context"
    )
    @request = @client.client_project_intakes.create!(
      title: "Fictional current record", project_type: "rails_bugfix",
      goal: "A" * 540, demo_consent_at: Time.current
    )
    @request.intake_messages.create!(role: "client", body: "Fictional first request")
    @request.intake_messages.create!(role: "assistant", body: "Template acknowledgement")
    @latest = @request.intake_messages.create!(role: "client", body: "Current fictional requirement at 320px.")
  end

  test "collapsed original and history keep latest client turn visible and mark only seen message" do
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path
    assert_equal 1, OwnerIntakeInbox.unread_for(owner: @owner).count

    visit admin_project_intakes_path
    assert_selector "header a.wa-inbox-nav .wa-unread-count", text: "1"
    visit project_intake_path(@request)
    assert_no_selector "header a.wa-inbox-nav .wa-unread-count"
    assert_selector "#intake-current .wa-context__latest-body", text: /320px/
    assert_selector "#intake-brief .wa-context__original:not([open])", visible: :all
    assert_selector "#intake-interview .wa-context__history:not([open])", visible: :all
    assert_equal @latest.id,
      OwnerIntakeReadState.find_by!(owner_user: @owner, project_intake: @request).last_seen_client_message_id

    find("#intake-interview .wa-context__history > summary").click
    assert_selector "#intake-conversation li", count: 3
    find("#intake-brief .wa-context__original > summary").click
    assert_selector "#intake-brief .wa-owner-intake__prose", text: /AAAAAA/

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
