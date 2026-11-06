require "test_helper"

class DayCalendarTest < ActionDispatch::IntegrationTest
  test "public day exposes all 24 hours and expands occupied intervals" do
    get calendar_day_url(date: "2023-01-19")

    assert_response :success
    assert_select "h1 time[datetime='2023-01-19']", text: /19 January 2023/
    assert_select "nav[aria-label='Calendar day navigation']"
    assert_select ".day-schedule[role='list'] > section.hour-row", count: 24
    assert_select "#hour-00.hour-row--quiet time", text: /00:00/
    assert_select "#hour-23.hour-row--busy time.hour-time", text: /23:00/
    assert_select "#hour-22 details.hour-disclosure[open]", count: 1
    assert_select "#hour-23 details.hour-disclosure[open]", count: 1
    assert_select "#hour-22 a[href=?]", consultation_path(consultations(:one))
    assert_select "#hour-23 a[href=?]", consultation_path(consultations(:one))
    assert_select ".day-add-link", count: 0
  end

  test "month calendar links each date and shows its event count" do
    get root_url(start_date: "2023-01-01")

    assert_response :success
    assert_select "a.calendar-day-link[href=?]", calendar_day_path(date: "2023-01-19")
    assert_select "time[datetime='2023-01-19']"
    assert_select ".calendar-day-count", minimum: 30
  end

  test "busy month cell caps visible events at two and links to full day" do
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

  test "month event counts include consultations begun before the displayed period" do
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

  test "cross-midnight consultations appear in the following day" do
    event = Consultation.create!(
      title: "Overnight technical session",
      start_time: Time.zone.local(2023, 1, 18, 23, 30),
      end_time: Time.zone.local(2023, 1, 19, 1, 15)
    )

    get calendar_day_url(date: "2023-01-19")

    assert_response :success
    assert_select "#hour-00 a[href=?]", consultation_path(event)
    assert_select "#hour-01 a[href=?]", consultation_path(event)
    assert_select "#hour-02 a[href=?]", consultation_path(event), count: 0
  end

  test "busy hour renders every event and advertises the count" do
    5.times do |i|
      Consultation.create!(
        title: "Consultation #{i}",
        start_time: Time.zone.local(2023, 1, 19, 9, 0),
        end_time: Time.zone.local(2023, 1, 19, 9, 45)
      )
    end

    get calendar_day_url(date: "2023-01-19")
    assert_response :success
    assert_select "#hour-09[aria-label='09:00 — 5 events']", count: 1
    assert_select "#hour-09 .hour-event", count: 5
    assert_select "#hour-09 .hour-event-list[tabindex='0']", count: 1
  end

  test "day date rejects unsupported dates" do
    ["garbage", "1212-12-12", "2101-01-01"].each do |date|
      get calendar_day_url(date: date)
      assert_redirected_to root_url
    end
  end

  test "signed in admin may open manual booking from each hour" do
    sign_in
    get calendar_day_url(date: "2026-11-06")

    assert_response :success
    assert_select "a.day-add-link", count: 24
    assert_select "a[href=?]", new_consultation_path(start_at: Time.zone.local(2026, 11, 6, 9).iso8601)

    get new_consultation_url(start_at: "2026-11-06T09:00:00Z")
    assert_response :success
    assert_select "input.rc-input[name='consultation[start_time]'][value^='2026-11-06T09:00']"
    assert_select "input.rc-input[name='consultation[end_time]'][value^='2026-11-06T10:00']"
    assert_select "input.rc-input[name='consultation[title]']"
  end

  test "bad schedule prefill does not crash admin form" do
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
