require "test_helper"

class DayCalendarTest < ActionDispatch::IntegrationTest
  test "public day shows 24 clickable hour intervals and one continuous card per consultation" do
    get calendar_day_url(date: "2023-01-19")

    assert_response :success
    assert_select "h1 time[datetime='2023-01-19']", text: /19 January 2023/
    assert_select "nav[aria-label='Calendar day navigation']"
    assert_select ".rc-time-axis-hour", count: 24
    assert_select "a.rc-hour-band", count: 24
    assert_select "#hour-00 time", text: /00:00/
    assert_select "#hour-23 time", text: /23:00/
    assert_select "a.rc-hour-band[href=?]", calendar_hour_path(date: "2023-01-19", hour: 9), count: 1

    # Fixture :one is 22:33–23:33, but must be rendered exactly once, not
    # duplicated into both 22:00 and 23:00.
    assert_select "article#event-#{consultations(:one).id}", count: 1
    assert_select "article#event-#{consultations(:one).id} a[href=?]",
                  consultation_path(consultations(:one)), count: 1
    assert_select ".rc-range-event", count: 1
    assert_select ".day-add-link", count: 0
  end

  test "every one-hour interval is viewable including an empty one" do
    get calendar_hour_url(date: "2023-01-19", hour: 9)
    assert_response :success
    assert_select "h1 time", text: "09:00"
    assert_select "h1 time", text: "10:00"
    assert_select "[role='status']", text: /No consultations/
    assert_select "a[href=?]", new_consultation_path, count: 0

    get calendar_hour_url(date: "2023-01-19", hour: 22)
    assert_response :success
    assert_select "a[href=?]", consultation_path(consultations(:one)), text: consultations(:one).title
    assert_select "h1 time", text: "22:00"
    assert_select "h1 time", text: "23:00"

    get calendar_hour_url(date: "2023-01-19", hour: 23)
    assert_response :success
    assert_select "a[href=?]", consultation_path(consultations(:one))
    assert_select "h1 time", text: "00:00"
    assert_select "a[href=?]", calendar_day_path(date: "2023-01-19", anchor: "hour-23")
  end

  test "month calendar links dates and shows event counts" do
    get root_url(start_date: "2023-01-01")

    assert_response :success
    assert_select "a.calendar-day-link[href=?]", calendar_day_path(date: "2023-01-19")
    assert_select "time[datetime='2023-01-19']"
    assert_select ".calendar-day-count", minimum: 30
    assert_select "a.calendar-day-link[aria-label='View Thursday, January 19, 2023']", count: 1
    assert_select "a.calendar-event-link[href=?]", consultation_path(consultations(:one)), count: 1
  end

  test "mobile primary navigation has distinct public routes and guarded create entry" do
    get root_url(start_date: "2023-01-19")
    assert_response :success

    assert_select "nav[aria-label='Mobile primary navigation']" do
      assert_select "a.rc-mobile-dock-item", count: 5
      assert_select "a[href=?]", root_path, count: 1
      assert_select "a[href=?]", calendar_day_path(date: Time.zone.today.iso8601), count: 1
      assert_select "a[href=?]", consultations_path, count: 1
      assert_select "a.rc-mobile-dock-item--create[href=?]", admin_login_path,
                    count: 1
      assert_select "a.rc-mobile-dock-item--create[aria-label='Sign in to add a consultation']", count: 1
      assert_select "a.rc-mobile-dock-item--create[href=?]", new_consultation_path, count: 0
    end

    sign_in
    get root_url(start_date: "2023-01-19")
    assert_response :success

    assert_select "nav[aria-label='Mobile primary navigation']" do
      assert_select "a.rc-mobile-dock-item--create[href=?]", new_consultation_path, count: 1
      assert_select "form[action=?]", admin_logout_path, count: 1
      assert_select "button[aria-label='Sign out of administrator session']", count: 1
    end
  end

  test "consultation actions distinguish calendar navigation from protected management" do
    multi_day = Consultation.create!(
      title: "Multi-day support",
      start_time: Time.zone.local(2023, 1, 18, 23, 30),
      end_time: Time.zone.local(2023, 1, 19, 1, 15)
    )

    get consultation_url(multi_day)
    assert_response :success
    assert_select "nav.rc-detail-actions[aria-label='Consultation actions']" do
      assert_select ".rc-detail-primary-actions > a", count: 3
      assert_select "a[aria-label='View in calendar']", count: 1
      assert_select "a[aria-label='See final day']", count: 1
      assert_select "a[aria-label='All consultations']", count: 1
      assert_select ".rc-detail-admin-actions", count: 0
    end

    sign_in
    get consultation_url(multi_day)
    assert_response :success
    assert_select ".rc-detail-admin-actions" do
      assert_select "a[aria-label='Edit this consultation']", count: 1
      assert_select "button[aria-label='Destroy this consultation']", count: 1
      assert_select "form[action=?]", consultation_path(multi_day), count: 1
    end
  end

  test "icon actions preserve text labels and remain decorative" do
    get root_url(start_date: "2023-01-19")
    assert_response :success

    assert_select "a.calendar-mobile-agenda-trigger[href='#month-events']" do
      assert_select "i.bi.bi-list-ul[aria-hidden='true']", count: 1
      assert_select "span.rc-action-label", text: "Events by date"
    end
    assert_select "nav[aria-label='Calendar month navigation']" do
      assert_select "i.bi.bi-chevron-left[aria-hidden='true']", count: 1
      assert_select "i.bi.bi-chevron-right[aria-hidden='true']", count: 1
    end

    get consultation_url(consultations(:one))
    assert_response :success
    assert_select "nav[aria-label='Consultation actions'] a" do
      assert_select "i.bi.bi-calendar-event[aria-hidden='true']", minimum: 1
    end

    get admin_login_url
    assert_response :success
    assert_select "button.rc-action.rc-action--primary[type='submit']" do
      assert_select "i.bi.bi-box-arrow-in-right[aria-hidden='true']", count: 1
      assert_select "span.rc-action-label", text: "Sign in"
    end
  end

  test "mobile agenda has independent day and consultation links" do
    get root_url(start_date: "2023-01-19")

    assert_response :success
    assert_select "section.calendar-mobile-agenda[aria-label='Consultations in the displayed month']", count: 1
    assert_select ".calendar-mobile-agenda-title", text: "Events in January 2023"
    assert_select "a.calendar-mobile-date-link[href=?]", calendar_day_path(date: "2023-01-19"), count: 1
    assert_select "a.calendar-mobile-event-link[href=?]", consultation_path(consultations(:one)), count: 1
    assert_select "a.calendar-day-link[href=?]", calendar_day_path(date: "2023-01-19"), count: 1
  end

  test "mobile agenda limits previews but preserves access to every busy day" do
    4.times do |index|
      Consultation.create!(
        title: "Additional session #{index}",
        start_time: Time.zone.local(2023, 1, 19, 9, index * 5),
        end_time: Time.zone.local(2023, 1, 19, 9, index * 5 + 5)
      )
    end

    get root_url(start_date: "2023-01-19")
    assert_response :success
    assert_select ".calendar-mobile-agenda-day[data-date='2023-01-19']" do
      assert_select "a.calendar-mobile-event-link", count: 2
      assert_select "a.calendar-mobile-more[href=?]", calendar_day_path(date: "2023-01-19"),
                    text: "View all 5 events", count: 1
    end
  end

  test "busy month cell caps previews at two and links to full day" do
    4.times do |index|
      Consultation.create!(
        title: "Extra event #{index}",
        start_time: Time.zone.local(2023, 1, 19, 9, index * 5),
        end_time: Time.zone.local(2023, 1, 19, 9, index * 5 + 5)
      )
    end

    get root_url(start_date: "2023-01-19")

    assert_response :success
    assert_select "a.calendar-more[href=?]", calendar_day_path(date: "2023-01-19"), text: "+ 3 more"
    assert_select "a.calendar-more[aria-label='View all 5 events on 2023-01-19']"
  end

  test "monthly event counts include consultations begun outside current month" do
    consultation = Consultation.create!(
      title: "Boundary event",
      start_time: Time.zone.local(2023, 1, 29, 23, 30),
      end_time: Time.zone.local(2023, 1, 30, 1, 30)
    )

    get root_url(start_date: "2023-02-01")

    assert_response :success
    assert_select "a.calendar-event-link[href=?]", consultation_path(consultation)
    assert_select ".calendar-event-name", text: "Boundary event"
    assert_select ".calendar-event-time", text: "Ongoing"
  end

  test "one overnight consultation is a single continuous event on each calendar date" do
    event = Consultation.create!(
      title: "Overnight technical session",
      start_time: Time.zone.local(2023, 1, 18, 23, 30),
      end_time: Time.zone.local(2023, 1, 19, 1, 15)
    )

    get calendar_day_url(date: "2023-01-18")
    assert_response :success
    assert_select "article#event-#{event.id}", count: 1
    assert_select "article#event-#{event.id} a[href=?]", consultation_path(event), count: 1
    assert_select "article#event-#{event.id} .rc-range-event-clock", text: /23:30.*24:00/m
    assert_select "article#event-#{event.id} .rc-range-event-exact-bar", count: 1

    get calendar_day_url(date: "2023-01-19")
    assert_response :success
    assert_select "article#event-#{event.id}", count: 1
    assert_select "article#event-#{event.id} a[href=?]", consultation_path(event), count: 1
    assert_select "article#event-#{event.id} .rc-range-event-clock", text: /00:00.*01:15/m
    assert_select "#hour-00 .rc-time-axis-count", text: "1"
    assert_select "#hour-01 .rc-time-axis-count", text: "1"
    assert_select "#hour-02 .rc-time-axis-count", count: 0

    get calendar_hour_url(date: "2023-01-19", hour: 1)
    assert_response :success
    assert_select "a[href=?]", consultation_path(event)
    get calendar_hour_url(date: "2023-01-19", hour: 2)
    assert_response :success
    assert_select "a[href=?]", consultation_path(event), count: 0
  end

  test "five overlapping events are five distinct cards with independent lanes" do
    5.times do |i|
      Consultation.create!(
        title: "Consultation #{i}",
        start_time: Time.zone.local(2023, 1, 19, 9),
        end_time: Time.zone.local(2023, 1, 19, 9, 45)
      )
    end

    get calendar_day_url(date: "2023-01-19")
    assert_response :success
    assert_select "#hour-09 .rc-time-axis-count", text: "5"
    assert_select ".rc-range-event", count: 6 # Includes fixture :one.
    assert_select "article.rc-range-event[data-lanes='5']", count: 5
    assert_select ".rc-day-canvas[style*='--rc-max-lanes: 5']"
  end

  test "consultation index and details offer calendar deep links" do
    event = consultations(:one)
    date = event.start_time.in_time_zone.to_date.iso8601
    get consultations_url
    assert_response :success
    assert_select "a[href=?]", consultation_path(event), text: event.title, count: 1
    assert_select "a[href=?]", calendar_day_path(date: date, anchor: "event-#{event.id}"), text: "View in calendar", count: 1
    get consultation_url(event)
    assert_response :success
    assert_select "a[href=?]", calendar_day_path(date: date, anchor: "event-#{event.id}"), text: "View in calendar", count: 1
  end

  test "today and day navigation lead to the 24-hour timeline" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", calendar_day_path(date: Time.zone.today.iso8601), text: /Today/
    get calendar_day_url(date: Time.zone.today.iso8601)
    assert_response :success
    assert_select ".rc-time-axis-hour", count: 24
  end

  test "invalid dates and hours are rejected without exposing errors" do
    ["garbage", "1212-12-12", "2101-01-01"].each do |date|
      get calendar_day_url(date: date)
      assert_redirected_to root_url
      get calendar_hour_url(date: date, hour: 10)
      assert_redirected_to root_url
    end

    ["-1", "24", "bogus", "09;delete", "1.5", ""].each do |hour|
      get calendar_hour_url(date: "2026-11-06", hour: hour)
      assert_redirected_to root_url
    end
  end

  test "signed in administrator can open manual creation for any selected interval" do
    sign_in
    get calendar_day_url(date: "2026-11-06")

    assert_response :success
    assert_select "a.rc-hour-band", count: 24
    assert_select "a[href=?]", new_consultation_path(start_at: Time.zone.local(2026, 11, 6, 9).iso8601), count: 0

    get calendar_hour_url(date: "2026-11-06", hour: 9)
    assert_response :success
    assert_select "a[href=?]", new_consultation_path(start_at: Time.zone.local(2026, 11, 6, 9).iso8601),
                  text: "Add consultation", count: 1

    get new_consultation_url(start_at: "2026-11-06T09:00:00Z")
    assert_response :success
    assert_select "input.rc-input[name='consultation[start_time]'][value^='2026-11-06T09:00']"
    assert_select "input.rc-input[name='consultation[end_time]'][value^='2026-11-06T10:00']"
  end

  test "invalid schedule prefill never crashes administrator form" do
    sign_in
    get new_consultation_url(start_at: "not-a-time")
    assert_response :success
    assert_select "input[name='consultation[start_time]']"
  end

  private

  def sign_in
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_redirected_to consultations_url
  end
end
