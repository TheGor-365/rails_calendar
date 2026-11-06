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
    assert_select "a.calendar-event-name[href=?]", consultation_path(consultation)
    assert_select "a.calendar-event-name", text: "Boundary event"
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

    get calendar_day_url(date: "2023-01-19")
    assert_response :success
    assert_select "article#event-#{event.id}", count: 1
    assert_select "article#event-#{event.id} a[href=?]", consultation_path(event), count: 1
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
