require "application_system_test_case"

class OwnerIntakeUnreadSystemTest < ApplicationSystemTestCase
  PASSWORD = "fictional-owner-unread-browser-password-2026".freeze

  setup do
    @owner = User.create!(email: "browser-inbox-owner@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(
      email: "browser-inbox-client@example.test", role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "browser-unread-local"
    )
    @intake = @client.client_project_intakes.create!(
      title: "Fictional browser unread request", project_type: "rails_bugfix",
      goal: "Inspect a synthetic Rails error without any real customer data.",
      demo_consent_at: Time.current
    )
    @intake.intake_messages.create!(role: "client", body: "Fictional client report.")
    @intake.intake_messages.create!(role: "assistant", body: "Local pilot confirmation only.")
  end

  test "unread nav badge clears only after opening detail and stays usable at 320px" do
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit admin_project_intakes_path
    assert_selector "header a.wa-inbox-nav .wa-unread-count", text: "1"
    assert_selector "nav.rc-mobile-dock--owner a.wa-inbox-mobile .wa-unread-count", text: "1", visible: :all
    assert_selector ".wa-requests__record--unread", count: 1

    within(".wa-requests__record--unread") do
      find("summary", text: @intake.title).click
      find("a[href='#{project_intake_path(@intake)}']").click
    end
    assert_current_path project_intake_path(@intake)
    assert_no_selector "header a.wa-inbox-nav .wa-unread-count"
    visit admin_project_intakes_path
    assert_no_selector ".wa-requests__record--unread"

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      dimensions = page.evaluate_script("({ page: document.documentElement.scrollWidth, viewport: window.innerWidth })")
      assert_operator dimensions["page"], :<=, dimensions["viewport"] + 1
      assert_selector "nav.rc-mobile-dock--owner a.wa-inbox-mobile", visible: true
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "requests menu uses bidirectional motion without horizontal overflow" do
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path
    visit admin_project_intakes_path(view: "outgoing")
    [400, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      menu = find(".wa-requests__more > summary")
      menu.click
      assert_selector ".wa-requests__more[open] .wa-requests__more-panel"
      dimensions = page.evaluate_script(<<~JS)
        (() => {
          const panel = document.querySelector(".wa-requests__more-panel").getBoundingClientRect();
          return {left: panel.left, right: panel.right, page: document.documentElement.scrollWidth, viewport: innerWidth};
        })()
      JS
      assert_operator dimensions["left"], :>=, -1
      assert_operator dimensions["right"], :<=, dimensions["viewport"] + 1
      assert_operator dimensions["page"], :<=, dimensions["viewport"] + 1
      if page.evaluate_script("CSS.supports('selector(details::details-content)') && CSS.supports('transition-behavior: allow-discrete') && !matchMedia('(prefers-reduced-motion: reduce)').matches")
        assert page.evaluate_script("getComputedStyle(document.querySelector('.wa-requests__more'), '::details-content').transitionDuration.includes('0.24s')")
      end
      menu.click
      assert_no_selector ".wa-requests__more[open]"
      if page.evaluate_script("CSS.supports('selector(details::details-content)') && CSS.supports('transition-behavior: allow-discrete') && !matchMedia('(prefers-reduced-motion: reduce)').matches")
        assert page.evaluate_script("getComputedStyle(document.querySelector('.wa-requests__more'), '::details-content').transitionDuration.includes('0.2s')")
      end
      assert_no_selector ".wa-requests__more-panel", visible: true
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

end
