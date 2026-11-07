require "test_helper"

class ConsultationsHelperTest < ActionView::TestCase
  include ConsultationsHelper

  test "exact durations use hours and minutes without rounding to coarse words" do
    start_time = Time.zone.local(2026, 11, 13, 11, 0)

    assert_equal "1 h 40 min", rc_consultation_duration(start_time, start_time + 100.minutes)
    assert_equal "30 min", rc_consultation_duration(start_time, start_time + 30.minutes)
    assert_equal "1 h", rc_consultation_duration(start_time, start_time + 1.hour)
    assert_equal "24 h", rc_consultation_duration(start_time, start_time + 24.hours)
  end

  test "legacy seconds are described as approximate without changing the instant" do
    start_time = Time.zone.local(2026, 11, 13, 11, 0, 7)
    end_time = start_time + 100.minutes + 10.seconds
    assert_equal "approximately 1 h 40 min", rc_consultation_duration(start_time, end_time)
    assert_equal 17, end_time.sec
  end

  test "missing and nonpositive intervals do not produce misleading durations" do
    t = Time.zone.local(2026, 11, 13, 11)
    assert_equal "Not available", rc_consultation_duration(nil, t)
    assert_equal "Not available", rc_consultation_duration(t, t)
    assert_equal "less than 1 min", rc_consultation_duration(t, t + 20.seconds)
  end
end
