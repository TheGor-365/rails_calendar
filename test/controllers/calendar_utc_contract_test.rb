require "test_helper"

class CalendarUtcContractTest < ActionDispatch::IntegrationTest
  test "calendar keeps an explicit UTC interpretation independent of DST dates" do
    assert_equal "UTC", Rails.application.config.time_zone
    assert_equal "UTC", Time.zone.name
    assert_equal :utc, ActiveRecord.default_timezone

    # Other regions change their clocks on these dates. The existing UTC
    # schedule remains a complete 24-hour timeline, not a 23/25-hour day.
    [Date.new(2026, 3, 8), Date.new(2026, 11, 1)].each do |date|
      get calendar_day_url(date: date.iso8601)
      assert_response :success
      assert_select ".rc-time-axis-hour", count: 24
      assert_select "#hour-00 time", text: "00:00"
      assert_select "#hour-23 time", text: "23:00"
      assert_select ".rc-muted", text: /UTC/
    end
  end

  test "events use half-open UTC day boundaries at midnight" do
    ending_at_midnight = Consultation.create!(
      title: "Day one only",
      start_time: Time.zone.local(2026, 11, 11, 23, 30),
      end_time: Time.zone.local(2026, 11, 12, 0, 0)
    )
    starting_at_midnight = Consultation.create!(
      title: "Day two only",
      start_time: Time.zone.local(2026, 11, 12, 0, 0),
      end_time: Time.zone.local(2026, 11, 12, 0, 30)
    )

    get calendar_day_url(date: "2026-11-11")
    assert_response :success
    assert_select "article#event-#{ending_at_midnight.id}", count: 1
    assert_select "article#event-#{starting_at_midnight.id}", count: 0

    get calendar_day_url(date: "2026-11-12")
    assert_response :success
    assert_select "article#event-#{ending_at_midnight.id}", count: 0
    assert_select "article#event-#{starting_at_midnight.id}", count: 1

    get calendar_hour_url(date: "2026-11-12", hour: 0)
    assert_response :success
    assert_select "a[href=?]", consultation_path(ending_at_midnight), count: 0
    assert_select "a[href=?]", consultation_path(starting_at_midnight), minimum: 1

    get calendar_hour_url(date: "2026-11-12", hour: 1)
    assert_response :success
    assert_select "a[href=?]", consultation_path(starting_at_midnight), count: 0
  end
end
