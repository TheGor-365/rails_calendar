require "application_system_test_case"

class StickyRequestSideNavigationTest < ApplicationSystemTestCase
  PASSWORD = "fictional-sticky-rail-browser-password-2026".freeze

  setup do
    @previous_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    AdminLoginWindow.delete_all
    @owner = User.create!(email: "sticky-rail-owner@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(
      email: "sticky-rail-client@example.test", role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "fictional-sticky-rail"
    )
    @intake = @client.client_project_intakes.create!(
      title: "Fictional pinned navigation", project_type: "rails_bugfix",
      goal: "A" * 920, demo_consent_at: Time.current
    )
    @intake.intake_messages.create!(role: "client", body: "A fictional client first message")
    @intake.intake_messages.create!(role: "assistant", body: "Template only; no paid AI")
    @intake.intake_messages.create!(role: "client", body: "A fictional second message")
  end

  teardown do
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @previous_pilot
  end

  test "owner's left rail follows scroll and links target actual authorized sections" do
    sign_in_as(@owner)
    visit project_intake_path(@intake)
    assert_selector ".wa-detail-shell[data-controller='wa-section-nav']"
    assert_selector ".wa-detail-shell__aside .wa-detail-shell__link", count: 5
    assert_selector ".wa-detail-shell__link[href='#intake-current'][aria-current='location']"
    assert_no_selector ".wa-owner-intake__jump"
    %w[intake-current intake-workflow intake-brief intake-interview intake-review].each do |id|
      assert_selector ".wa-detail-shell__aside a[href='##{id}']"
      assert_selector "##{id}"
    end
    assert_no_selector ".wa-detail-shell__aside a[href='#intake-spec']"
    assert_no_selector "#intake-review form[action$='/reply']"

    page.driver.browser.manage.window.resize_to(1440, 900)
    computed = page.evaluate_script("({ position: getComputedStyle(document.querySelector('.wa-detail-shell__aside')).position, left: document.querySelector('.wa-detail-shell__aside').getBoundingClientRect().left, main: document.querySelector('.wa-detail-shell__main').getBoundingClientRect().left })")
    assert_equal "sticky", computed["position"]
    assert_operator computed["left"], :<, computed["main"]
    page.execute_script("window.scrollTo(0, 600)")
    assert_operator page.evaluate_script("document.querySelector('.wa-detail-shell__aside').getBoundingClientRect().top"), :>=, 0

    find(".wa-detail-shell__aside a[href='#intake-interview']").click
    assert_equal "#intake-interview", page.evaluate_script("window.location.hash")
    assert_selector ".wa-detail-shell__link[href='#intake-interview'][aria-current='location']"

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      assert_equal "static", page.evaluate_script("getComputedStyle(document.querySelector('.wa-detail-shell__aside')).position")
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1440, 900)
  end

  test "owner Requests hub has one primary action, accessible tools and deep-link tabs" do
    sign_in_as(@owner)
    visit admin_project_intakes_path

    assert_selector ".wa-requests .rc-page-hero__actions > a.rc-action--primary", count: 1
    assert_selector ".wa-requests__more > summary", count: 1
    assert_selector ".wa-requests__tab[data-view='incoming'][aria-selected='true']"
    assert_selector "#wa-requests-incoming:not([hidden])"

    click_button "Outgoing"
    assert_selector ".wa-requests__tab[data-view='outgoing'][aria-selected='true']"
    assert_selector "#wa-requests-outgoing:not([hidden])"
    assert_equal "outgoing", page.evaluate_script("new URLSearchParams(window.location.search).get('view')")

    click_button "Incoming"
    assert_selector "#wa-requests-incoming:not([hidden])"
    assert_equal "incoming", page.evaluate_script("new URLSearchParams(window.location.search).get('view')")

    # The explicit URL state must win over any previously saved tab preference.
    visit admin_project_intakes_path(view: "outgoing")
    assert_selector ".wa-requests__tab[data-view='outgoing'][aria-selected='true']"
    visit admin_project_intakes_path(view: "incoming")
    assert_selector ".wa-requests__tab[data-view='incoming'][aria-selected='true']"

    find(".wa-requests__more > summary").click
    assert_selector ".wa-requests__more-panel a[href='#{owner_services_path}']"
    assert_selector ".wa-requests__more-panel a[href='#{new_project_intake_path}']"

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1

      # The open popover must stay fully visible, not merely be clipped offscreen.
      popover = page.evaluate_script("(() => { const r = document.querySelector('.wa-requests__more-panel').getBoundingClientRect(); return {left: r.left, right: r.right, viewport: innerWidth}; })()")
      assert_operator popover["left"], :>=, -1
      assert_operator popover["right"], :<=, popover["viewport"] + 1
    end
    assert_equal 0, AiSpendEntry.count
  ensure
    page.driver.browser.manage.window.resize_to(1440, 900)
  end

  test "client rail has only available links, reply navigation, and no horizontal overflow" do
    sign_in_as(@client)
    visit client_request_path(@intake)
    assert_selector ".wa-detail-shell__aside .wa-detail-shell__link", count: 5
    assert_selector ".wa-detail-shell__link[href='#intake-current'][aria-current='location']"
    assert_selector ".wa-detail-shell__link[href='#client-request-description']"
    assert_selector ".wa-detail-shell__link[href='#client-request-conversation-heading']"
    assert_selector ".wa-detail-shell__link[href='#client-request-reply']"
    assert_selector ".wa-detail-shell__link[href='#client-request-spec']"
    assert_no_selector ".wa-detail-shell__link[href='#intake-review']"
    assert_no_selector ".wa-detail-shell__link[href='#client-request-milestones']"

    find(".wa-detail-shell__aside a[href='#client-request-reply']").click
    assert_equal "#client-request-reply", page.evaluate_script("window.location.hash")
    assert_selector "form#client-reply-form"
    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      assert_equal "static", page.evaluate_script("getComputedStyle(document.querySelector('.wa-detail-shell__aside')).position")
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1440, 900)
  end

  private

  def sign_in_as(user)
    visit sign_in_path
    fill_in "Email address", with: user.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path(user.role == "client" ? client_home_path : workspace_path)
  end
end
