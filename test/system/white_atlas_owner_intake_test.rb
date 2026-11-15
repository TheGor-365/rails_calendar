require "application_system_test_case"

class WhiteAtlasOwnerIntakeTest < ApplicationSystemTestCase
  PASSWORD = "synthetic-intake-ux-browser-password-2026".freeze

  setup do
    @owner = User.create!(email: "intake-ux-owner@example.test", role: "owner", password: PASSWORD)
    @intake = ProjectIntake.create!(
      title: "Synthetic API request", project_type: "api_integration",
      goal: "A fictional API needs a safe regression verification plan.",
      demo_consent_at: Time.current
    )
    @intake.intake_messages.create!(role: "client", body: "Fictional client question.\nNo real credentials.")
    @intake.intake_messages.create!(role: "assistant", body: "Suggested next question for a fictional API.")
  end

  test "owner can filter interview by role without deleting messages or navigating" do
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit project_intake_path(@intake)
    assert_selector "#intake-brief .wa-owner-intake__prose", text: /fictional API/i
    assert_selector "#intake-conversation li", count: 2
    assert_selector "button[data-wa-intake-thread-role-param='all'][aria-pressed='true']"

    find("button[data-wa-intake-thread-role-param='client']").click
    assert_selector "#intake-conversation li[data-wa-intake-thread-role='client']:not([hidden])", count: 1
    assert_selector "#intake-conversation li[data-wa-intake-thread-role='assistant'][hidden]", visible: :all, count: 1
    assert_selector "button[data-wa-intake-thread-role-param='client'][aria-pressed='true']"
    assert_equal project_intake_path(@intake), current_path

    find("button[data-wa-intake-thread-role-param='assistant']").click
    assert_selector "#intake-conversation li[data-wa-intake-thread-role='client'][hidden]", visible: :all, count: 1
    assert_selector "#intake-conversation li[data-wa-intake-thread-role='assistant']:not([hidden])", count: 1

    find("button[data-wa-intake-thread-role-param='all']").click
    assert_selector "#intake-conversation li:not([hidden])", count: 2
    assert_selector "#intake-review"
    assert_selector "#intake-current .wa-context__latest-body", text: /Fictional client question/
    fill_in "Search displayed history", with: "credentials"
    assert_selector "#intake-conversation li:not([hidden])", count: 1
    fill_in "Search displayed history", with: ""
    assert_selector "#intake-conversation li:not([hidden])", count: 2
    find("select[data-wa-intake-thread-target='order']").select("Newest first")
    assert_selector "#intake-conversation li:first-child[data-wa-intake-thread-role='assistant']"

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      bounds = page.evaluate_script("({ page: document.documentElement.scrollWidth, viewport: window.innerWidth })")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
