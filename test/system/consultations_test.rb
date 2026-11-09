require "application_system_test_case"

class ConsultationsTest < ApplicationSystemTestCase
  setup do
    @consultation = consultations(:one)
  end

  test "visitor can navigate the month with accessible calendar semantics" do
    visit root_url(start_date: "2023-01-01")
    assert_selector "nav[aria-label='Calendar month navigation']"
    assert_selector ".calendar-scroll-region[tabindex='0']"
    assert_selector "time.calendar-day-label[datetime='2023-01-19']"
    click_on "Next"
    assert_selector ".calendar-title", text: "February 2023"
  end

  test "calendar month day hit targets and event cards navigate independently" do
    visit root_url(start_date: "2023-01-01")
    find("a.calendar-event-link[href='#{consultation_path(@consultation)}']").click
    assert_current_path consultation_path(@consultation)
    click_on "View in calendar"
    assert_current_path calendar_day_path(date: "2023-01-19")
    assert_selector ".rc-time-axis-hour", count: 24
    visit root_url(start_date: "2023-01-01")
    find("time.calendar-day-label[datetime='2023-01-19']").click
    assert_current_path calendar_day_path(date: "2023-01-19")
  end

  test "mobile calendar fits seven days and preserves independent day event and hour navigation" do
    [320, 390, 430].each do |viewport_width|
      page.driver.browser.manage.window.resize_to(viewport_width, 932)
      visit root_url(start_date: "2023-01-19")

      assert_selector ".calendar-mobile-agenda", visible: true
      assert_selector "a.calendar-mobile-agenda-trigger[href='#month-events']", visible: true
      assert_selector "a.calendar-mobile-event-link[href='#{consultation_path(@consultation)}']", visible: true
      assert_no_selector ".calendar-grid .calendar-event-link", visible: true

      dimensions = page.evaluate_script(<<~JS)
        (() => {
          const first = document.querySelector("a.calendar-day-link[href*='2023-01-16']");
          const sunday = document.querySelector("a.calendar-day-link[href*='2023-01-22']");
          return {
            firstLeft: first.getBoundingClientRect().left,
            sundayRight: sunday.getBoundingClientRect().right,
            documentWidth: document.documentElement.scrollWidth,
            viewportWidth: window.innerWidth
          };
        })()
      JS

      assert_operator dimensions["firstLeft"], :>=, 0, "Monday is clipped at #{viewport_width}px"
      assert_operator dimensions["sundayRight"], :<=, dimensions["viewportWidth"] + 1,
                      "Sunday is off-screen at #{viewport_width}px"
      assert_operator dimensions["documentWidth"], :<=, dimensions["viewportWidth"] + 1,
                      "Document overflows at #{viewport_width}px"

      find("a.calendar-mobile-event-link[href='#{consultation_path(@consultation)}']").click
      assert_current_path consultation_path(@consultation)

      visit root_url(start_date: "2023-01-19")
      find("a.calendar-day-link[href*='2023-01-19']").click
      assert_current_path calendar_day_path(date: "2023-01-19")
      find("#hour-22 a.rc-time-axis-link").click
      assert_current_path calendar_hour_path(date: "2023-01-19", hour: 22)
      assert_link @consultation.title
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "mobile bottom dock stays fixed while detail actions stay on one row" do
    multi_day = Consultation.create!(
      title: "Mobile navigation QA",
      start_time: Time.zone.local(2023, 1, 18, 23, 30),
      end_time: Time.zone.local(2023, 1, 19, 1, 15)
    )

    [320, 390, 430].each do |viewport_width|
      page.driver.browser.manage.window.resize_to(viewport_width, 932)
      visit consultation_url(multi_day)
      assert_selector "nav.rc-mobile-dock", visible: true
      assert_no_selector ".app-nav > a.rc-nav-link", visible: true
      assert_selector ".rc-detail-primary-actions > a", count: 3

      layout = page.evaluate_script(<<~JS)
        (() => {
          const dock = document.querySelector(".rc-mobile-dock");
          const actions = [...document.querySelectorAll(".rc-detail-primary-actions > a")];
          const positions = actions.map(el => el.getBoundingClientRect());
          return {
            dockPosition: getComputedStyle(dock).position,
            cssRelease: getComputedStyle(document.documentElement)
              .getPropertyValue("--rc-mobile-dock-release").trim(),
            dockBottom: dock.getBoundingClientRect().bottom,
            dockHeight: dock.getBoundingClientRect().height,
            dockCenter: (dock.getBoundingClientRect().left + dock.getBoundingClientRect().right) / 2,
            dockWidth: dock.getBoundingClientRect().width,
            iconFont: getComputedStyle(dock.querySelector(".rc-mobile-dock-icon"), "::before").fontFamily,
            viewportHeight: window.innerHeight,
            contentCenter: (() => { const r = document.querySelector("main#main-content").getBoundingClientRect();
              return (r.left + r.right) / 2; })(),
            pageWidth: document.documentElement.scrollWidth,
            viewportWidth: window.innerWidth,
            firstActionLeft: Math.min(...positions.map(p => p.left)),
            lastActionRight: Math.max(...positions.map(p => p.right)),
            rowDrift: Math.max(...positions.map(p => p.top)) - Math.min(...positions.map(p => p.top)),
            bottomPadding: parseFloat(getComputedStyle(document.body).paddingBottom)
          };
        })()
      JS
      assert_equal "fixed", layout["dockPosition"]
      assert_equal "rc014b-20261107", layout["cssRelease"], "Current Sass bundle is not loaded"
      assert_includes layout["iconFont"].downcase, "bootstrap-icons"
      assert_in_delta layout["viewportHeight"], layout["dockBottom"], 1
      assert_in_delta layout["contentCenter"], layout["dockCenter"], 1,
                      "Dock must align with centered application content"
      assert_operator layout["dockWidth"], :<=, 430
      assert_operator layout["dockWidth"], :<=, layout["viewportWidth"] + 1
      assert_operator layout["pageWidth"], :<=, layout["viewportWidth"] + 1
      assert_operator layout["firstActionLeft"], :>=, 0
      assert_operator layout["lastActionRight"], :<=, layout["viewportWidth"] + 1
      assert_operator layout["rowDrift"], :<=, 1
      assert_operator layout["bottomPadding"], :>=, layout["dockHeight"]
    end

    # Verify that the dock is pinned to the viewport, not the document footer:
    # this long schedule can be scrolled to the bottom on every mobile size.
    visit calendar_day_url(date: "2023-01-19")
    assert_selector "nav.rc-mobile-dock", visible: true
    # Force a scrollable fixture even when browser zoom/viewport height changes.
    # This tests fixed positioning, not the schedule's incidental pixel height.
    page.execute_script("document.querySelector('main#main-content').style.minHeight = '2200px'")
    # Bootstrap sets scroll-behavior: smooth, making an immediate scrollY
    # assertion race with the CSS animation. Force deterministic test scroll.
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'; window.scrollTo(0, 0)")
    scrollBefore = page.evaluate_script("window.scrollY")
    page.execute_script("window.scrollTo(0, 2000)")
    scrollAfter = page.evaluate_script("window.scrollY")
    assert_operator scrollAfter, :>, scrollBefore, "Fixed dock must remain visible after a real document scroll"
    dockAfterScroll = page.evaluate_script(<<~JS)
      (() => {
        const dock = document.querySelector(".rc-mobile-dock").getBoundingClientRect();
        return {bottom: dock.bottom, center: (dock.left + dock.right) / 2,
                viewportHeight: window.innerHeight,
                contentCenter: (() => { const r = document.querySelector("main#main-content").getBoundingClientRect();
                  return (r.left + r.right) / 2; })()};
      })()
    JS
    assert_in_delta dockAfterScroll["viewportHeight"], dockAfterScroll["bottom"], 1
    assert_in_delta dockAfterScroll["contentCenter"], dockAfterScroll["center"], 1

    find("nav.rc-mobile-dock a.rc-mobile-dock-item--create").click
    assert_current_path admin_login_path
    sign_in_as_admin
    find("nav.rc-mobile-dock a.rc-mobile-dock-item--create").click
    assert_current_path new_consultation_path
    find("nav.rc-mobile-dock button[aria-label='Sign out of administrator session']").click
    assert_text "Administrator signed out"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "mobile reschedule link and overlap advisory stay accessible on narrow screens" do
    collision = Consultation.create!(
      title: "Mobile overlap inspection",
      start_time: Time.zone.local(2023, 1, 19, 23, 0),
      end_time: Time.zone.local(2023, 1, 19, 23, 30)
    )

    sign_in_as_admin

    [320, 390, 430].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      visit consultations_url
      assert_selector "nav.rc-mobile-dock", visible: true
      find("a[aria-label='Reschedule #{@consultation.title}']").click
      assert_current_path edit_consultation_path(@consultation)
      assert_selector "input#consultation_start_time", visible: true
      assert_selector ".rc-overlap-notice a[href='#{consultation_path(collision)}']", visible: true

      dimensions = page.evaluate_script(<<~JS)
        (() => ({
          page: document.documentElement.scrollWidth,
          viewport: window.innerWidth,
          noticeRight: document.querySelector(".rc-overlap-notice").getBoundingClientRect().right,
          dockBottom: document.querySelector(".rc-mobile-dock").getBoundingClientRect().bottom,
          viewportHeight: window.innerHeight
        }))()
      JS
      assert_operator dimensions["page"], :<=, dimensions["viewport"] + 1
      assert_operator dimensions["noticeRight"], :<=, dimensions["viewport"] + 1
      assert_in_delta dimensions["viewportHeight"], dimensions["dockBottom"], 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "mobile reschedule reason and admin-only history fit 320 390 and 430 pixels" do
    record = consultations(:two)
    ConsultationRescheduleEvent.create!(
      consultation_id: record.id,
      old_start_time: record.start_time,
      old_end_time: record.end_time,
      new_start_time: record.start_time + 5.minutes,
      new_end_time: record.end_time + 5.minutes,
      actor_label: "administrator",
      reason: "Mobile audit visibility regression",
      created_at: Time.current
    )
    sign_in_as_admin

    [320, 390, 430].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)

      visit edit_consultation_url(record)
      assert_selector "#consultation_reschedule_reason", visible: true
      assert_text "Reason for time change"
      assert_selector "nav.rc-mobile-dock", visible: true

      visit consultation_url(record)
      assert_selector "#reschedule-history-title", text: "Reschedule history"
      assert_text "Mobile audit visibility regression"
      assert_selector "nav.rc-mobile-dock", visible: true

      layout = page.evaluate_script(<<~JS)
        (() => {
          const dock = document.querySelector("nav.rc-mobile-dock").getBoundingClientRect();
          return {
            scrollWidth: document.documentElement.scrollWidth,
            innerWidth: window.innerWidth,
            dockBottom: dock.bottom,
            windowHeight: window.innerHeight
          };
        })()
      JS
      assert_operator layout["scrollWidth"], :<=, layout["innerWidth"] + 1
      assert_in_delta layout["windowHeight"], layout["dockBottom"], 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "desktop hides the mobile bottom dock" do
    page.driver.browser.manage.window.resize_to(1280, 900)
    visit consultation_url(@consultation)
    assert_no_selector "nav.rc-mobile-dock", visible: true
    assert_selector ".app-nav > a.rc-nav-link", visible: true
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "desktop month retains inline event previews" do
    page.driver.browser.manage.window.resize_to(1280, 900)
    visit root_url(start_date: "2023-01-19")

    assert_selector "a.calendar-event-link[href='#{consultation_path(@consultation)}']", visible: true
    assert_no_selector ".calendar-mobile-agenda", visible: true
    assert_no_selector ".calendar-mobile-agenda-trigger", visible: true
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "mobile search form and filtered deep links remain fully reachable" do
    [320, 390, 430].each do |viewport_width|
      page.driver.browser.manage.window.resize_to(viewport_width, 932)
      visit consultations_url

      assert_selector "form.rc-consultation-filters[role='search']", visible: true
      assert_selector "nav.rc-mobile-dock", visible: true

      fill_in "Title contains", with: "MyString"
      click_on "Apply filters"

      assert_selector "li#consultation_#{@consultation.id}", visible: true
      assert_selector "li.rc-record", count: 1
      assert_link "View in calendar"
      assert_link "Clear"

      layout = page.evaluate_script(<<~JS)
        (() => ({
          docWidth: document.documentElement.scrollWidth,
          viewportWidth: window.innerWidth,
          searchWidth: document.querySelector(".rc-consultation-filters").getBoundingClientRect().width,
          searchRight: document.querySelector(".rc-consultation-filters").getBoundingClientRect().right,
          dockBottom: document.querySelector(".rc-mobile-dock").getBoundingClientRect().bottom,
          viewportHeight: window.innerHeight
        }))()
      JS
      assert_operator layout["docWidth"], :<=, layout["viewportWidth"] + 1
      assert_operator layout["searchRight"], :<=, layout["viewportWidth"] + 1
      assert_in_delta layout["viewportHeight"], layout["dockBottom"], 1

      click_on "View in calendar"
      assert_current_path calendar_day_path(date: "2023-01-19")
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "consultation detail shows exact scheduled duration in hours and minutes" do
    start = Time.zone.local(2026, 11, 13, 11)
    event = Consultation.create!(
      title: "Duration sample",
      start_time: start,
      end_time: start + 100.minutes
    )
    visit consultation_url(event)
    assert_selector ".rc-detail-meta", text: /Duration: 1 h 40 min/
    assert_no_text "about 2 hours"
  end

  test "anonymous visitors can browse without editing controls" do
    visit consultations_url
    assert_selector "h1", text: "Consultations"
    assert_no_link "New consultation"

    visit consultation_url(@consultation)
    assert_no_link "Edit this consultation"
    assert_no_button "Destroy this consultation"
  end

  test "anonymous visitor cannot open administrative forms" do
    visit new_consultation_url
    assert_current_path admin_login_path
    assert_selector "h1", text: "Administrator sign-in"

    visit edit_consultation_url(@consultation)
    assert_current_path admin_login_path
  end

  test "administrator can create consultation" do
    sign_in_as_admin
    visit consultations_url
    click_on "New consultation"

    fill_in "Description", with: @consultation.description
    fill_in "End time", with: @consultation.end_time.change(sec: 0)
    fill_in "Start time", with: @consultation.start_time.change(sec: 0)
    fill_in "Title", with: @consultation.title
    click_on "Create Consultation"

    assert_text "Consultation was successfully created"
  end

  test "administrator can update consultation" do
    sign_in_as_admin
    visit consultation_url(@consultation)
    click_on "Edit this consultation"

    fill_in "Title", with: "Updated consultation"
    click_on "Update Consultation"

    assert_text "Consultation was successfully updated"
    assert_text "Updated consultation"
  end

  test "canceling the exact-record delete dialog leaves the consultation intact" do
    sign_in_as_admin
    visit consultation_url(@consultation)

    original_title = @consultation.title
    original_start = @consultation.start_time
    original_end = @consultation.end_time

    dismiss_confirm(/Delete consultation ##{@consultation.id}.*#{Regexp.escape(original_title)}.*cannot be undone/) do
      click_on "Destroy this consultation"
    end

    assert_current_path consultation_path(@consultation)
    assert_selector "h1", text: "Consultation details"
    assert_equal original_title, @consultation.reload.title
    assert_equal original_start, @consultation.start_time
    assert_equal original_end, @consultation.end_time
    assert_selector "button[aria-label='Destroy this consultation']", visible: true
  end

  test "administrator can destroy consultation" do
    sign_in_as_admin
    visit consultation_url(@consultation)
    accept_confirm(/Delete consultation ##{@consultation.id}.*#{Regexp.escape(@consultation.title)}.*cannot be undone/) do
      click_on "Destroy this consultation"
    end

    assert_text "Consultation was successfully destroyed"
  end

  test "signing out hides administrative actions" do
    sign_in_as_admin
    visit consultations_url
    assert_link "New consultation"
    click_on "Sign out"

    assert_text "Administrator signed out"
    visit consultations_url
    assert_no_link "New consultation"
  end


  test "visitor sees one continuous card, can drill into any hour, and open the consultation" do
    visit root_url(start_date: "2023-01-01")
    find("a.calendar-day-link[href*='2023-01-19']").click

    assert_current_path calendar_day_path(date: "2023-01-19")
    assert_selector ".rc-time-axis-hour", count: 24
    assert_selector "a.rc-hour-band", count: 24
    assert_selector "article#event-#{@consultation.id}", count: 1
    assert_no_link "Add consultation"

    find("a.rc-hour-band[href*='hour=22']").click
    assert_current_path calendar_hour_path(date: "2023-01-19", hour: 22)
    assert_selector "h1", text: "22:00"
    assert_link @consultation.title

    click_on @consultation.title
    assert_current_path consultation_path(@consultation)
  end

  test "long consultation renders once per day and neighboring hours stay clickable" do
    long_event = Consultation.create!(
      title: "Long support session",
      start_time: Time.zone.local(2023, 1, 19, 0, 15),
      end_time: Time.zone.local(2023, 1, 19, 23, 15)
    )

    visit calendar_day_url(date: "2023-01-19")
    assert_selector "article#event-#{long_event.id}", count: 1
    assert_selector "article#event-#{long_event.id} a", count: 1
    assert_selector ".rc-time-axis-hour", count: 24

    # The large event intentionally covers the band; the left time axis
    # provides an independent click target for its interval.
    find("#hour-12 a.rc-time-axis-link").click
    assert_current_path calendar_hour_path(date: "2023-01-19", hour: 12)
    assert_link "Long support session"
  end

  test "administrator manually creates a consultation from a selected time interval" do
    sign_in_as_admin
    visit calendar_day_url(date: "2026-11-06")
    find("a.rc-hour-band[href*='hour=9']").click

    assert_current_path calendar_hour_path(date: "2026-11-06", hour: 9)
    click_on "Add consultation"

    assert_selector "h1", text: "New consultation"
    assert_field "Start time", with: /2026-11-06T09:00/
    assert_field "End time", with: /2026-11-06T10:00/

    fill_in "Title", with: "Project kickoff"
    click_on "Create Consultation"

    assert_text "Consultation was successfully created"
    assert_text "Project kickoff"
  end

  private

  def sign_in_as_admin
    visit admin_login_url
    fill_in "Username", with: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME")
    fill_in "Password", with: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    click_button "Sign in"
    assert_text "Administrator signed in"
  end
end
