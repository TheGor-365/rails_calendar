require "test_helper"

class DayCalendarTest < ActionDispatch::IntegrationTest
  test "public day screen displays exactly 24 hourly rows" do
    get calendar_day_url(date: "2023-01-19")

    assert_response :success
    assert_select "h1 time[datetime='2023-01-19']", text: /19 January 2023/
    assert_select "nav[aria-label='Calendar day navigation']"
    assert_select "table.day-timeline tbody tr", count: 24
    assert_select "tr#hour-00 time", text: /00:00/
    assert_select "tr#hour-23 time", text: /23:00/
    assert_select "tr#hour-22 a[href=?]", consultation_path(consultations(:one))
    assert_select "tr#hour-23 a[href=?]", consultation_path(consultations(:one))
    assert_select ".day-add-link", count: 0
  end

  test "month calendar links dates to public day schedule" do
    get root_url(start_date: "2023-01-01")

    assert_response :success
    assert_select "a.calendar-day-link[href=?]", calendar_day_path(date: "2023-01-19")
  end

  test "consultations crossing midnight are visible in the next day" do
    event = Consultation.create!(
      title: "Overnight technical session",
      start_time: Time.zone.local(2023, 1, 18, 23, 30),
      end_time: Time.zone.local(2023, 1, 19, 1, 15)
    )

    get calendar_day_url(date: "2023-01-19")

    assert_response :success
    assert_select "tr#hour-00 a[href=?]", consultation_path(event)
    assert_select "tr#hour-01 a[href=?]", consultation_path(event)
    assert_select "tr#hour-02 a[href=?]", consultation_path(event), count: 0
  end

  test "day date parameter rejects invalid or unsupported dates" do
    ["garbage", "1212-12-12", "2101-01-01"].each do |date|
      get calendar_day_url(date: date)
      assert_redirected_to root_url
    end
  end

  test "signed in administrator can launch manual creation at any hour" do
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_redirected_to consultations_url

    get calendar_day_url(date: "2026-11-06")

    assert_response :success
    assert_select "a.day-add-link", count: 24
    assert_select "a[href=?]", new_consultation_path(start_at: Time.zone.local(2026, 11, 6, 9).iso8601)

    get new_consultation_url(start_at: "2026-11-06T09:00:00Z")
    assert_response :success
    assert_select "input[name='consultation[start_time]'][value^='2026-11-06T09:00']"
    assert_select "input[name='consultation[end_time]'][value^='2026-11-06T10:00']"
  end

  test "invalid prefill never crashes the administrator form" do
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }

    get new_consultation_url(start_at: "not-a-time")
    assert_response :success
    assert_select "input[name='consultation[start_time]']"
  end
end
