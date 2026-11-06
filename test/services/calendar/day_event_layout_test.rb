require "test_helper"

class Calendar::DayEventLayoutTest < ActiveSupport::TestCase
  setup do
    @day_start = Time.zone.local(2026, 11, 7)
    @day_end = @day_start + 1.day
  end

  test "a 90-minute consultation is one event with minute-accurate placement" do
    event = consultation("Work session", 10, 30, 12, 0)
    layout = layout_for(event)

    assert_equal 1, layout.items.size
    item = layout.items.first
    assert_equal event.id, item.consultation.id
    assert_in_delta 441.0, item.start_px, 0.01
    assert_in_delta 63.0, item.height_px, 0.01
    assert_equal "10:30", item.visible_start_label
    assert_equal "12:00", item.visible_end_label
    assert_in_delta item.start_px, item.real_start_px, 0.01
    assert_in_delta item.height_px, item.real_height_px, 0.01
    assert_equal 0, item.lane
    assert_equal 1, item.lanes
  end

  test "overlapping events receive different lanes but disjoint events reuse width" do
    a = consultation("First", 10, 0, 12, 0)
    b = consultation("Second", 11, 0, 13, 0)
    c = consultation("Evening", 18, 0, 19, 0)

    layout = layout_for(a, b, c)
    assert_equal 3, layout.items.size
    assert_equal 2, layout.max_lanes
    simultaneous = layout.items.select { |item| [a.id, b.id].include?(item.consultation.id) }
    assert_equal [0, 1], simultaneous.map(&:lane).sort
    assert simultaneous.all? { |item| item.lanes == 2 }
    assert_equal 1, layout.items.find { |item| item.consultation.id == c.id }.lanes
  end

  test "short neighboring consultations reserve sufficient visual space" do
    a = consultation("Quick A", 9, 0, 9, 5)
    b = consultation("Quick B", 9, 15, 9, 20)

    layout = layout_for(a, b)
    assert_equal 2, layout.max_lanes
    assert layout.items.all? { |item| item.height_px >= Calendar::DayEventLayout::MIN_CARD_HEIGHT_PX }
    assert_equal [0, 1], layout.items.map(&:lane).sort
  end

  test "long overnight event is clipped to each date but never duplicated" do
    event = Consultation.create!(
      title: "Overnight",
      start_time: Time.zone.local(2026, 11, 7, 23, 54),
      end_time: Time.zone.local(2026, 11, 8, 22, 53)
    )

    first_day = layout_for(event)
    assert_equal 1, first_day.items.size
    assert first_day.items.first.continues_into_next_day
    assert_equal "23:54", first_day.items.first.visible_start_label
    assert_equal "24:00", first_day.items.first.visible_end_label
    assert_in_delta 4.2, first_day.items.first.real_height_px, 0.01
    assert_operator first_day.items.first.height_px, :>, first_day.items.first.real_height_px
    refute first_day.items.first.continues_from_previous_day
    assert_in_delta Calendar::DayEventLayout::DAY_HEIGHT_PX,
                    first_day.items.first.start_px + first_day.items.first.height_px, 0.01

    next_day_start = @day_end
    next_day = Calendar::DayEventLayout.new(
      consultations: [event],
      day_start: next_day_start,
      day_end: next_day_start + 1.day
    )
    assert_equal 1, next_day.items.size
    assert next_day.items.first.continues_from_previous_day
    assert_equal "00:00", next_day.items.first.visible_start_label
    assert_equal "22:53", next_day.items.first.visible_end_label
    refute next_day.items.first.continues_into_next_day
    assert_equal 0, next_day.items.first.start_px
    assert_in_delta 22 * 42 + 53 * 0.7, next_day.items.first.height_px, 0.01
  end

  test "no consultations produces zero cards and a single empty lane" do
    layout = layout_for
    assert_empty layout.items
    assert_equal 1, layout.max_lanes
  end

  private

  def consultation(title, from_hour, from_minute, to_hour, to_minute)
    Consultation.create!(
      title: title,
      start_time: Time.zone.local(2026, 11, 7, from_hour, from_minute),
      end_time: Time.zone.local(2026, 11, 7, to_hour, to_minute)
    )
  end

  def layout_for(*events)
    Calendar::DayEventLayout.new(
      consultations: events,
      day_start: @day_start,
      day_end: @day_end
    )
  end
end
