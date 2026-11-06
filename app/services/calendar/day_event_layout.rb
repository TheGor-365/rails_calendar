# frozen_string_literal: true

module Calendar
  # Positions each consultation ONCE on a continuous 00:00–24:00 day.
  # Cards that cover several hours span the corresponding visual interval.
  # Overlapping (including visually overlapping short) cards occupy separate
  # lanes; disjoint clusters reclaim the full width.
  #
  # Rendering assumes the application timezone is UTC. Introducing per-user
  # timezone/DST support requires an explicit 23/25-hour day design.
  class DayEventLayout
    HOUR_HEIGHT_PX = 42.0
    DAY_MINUTES = 24 * 60
    DAY_HEIGHT_PX = HOUR_HEIGHT_PX * 24
    MIN_CARD_HEIGHT_PX = 34.0

    Item = Struct.new(
      :consultation, :start_px, :height_px, :lane, :lanes,
      :real_start_px, :real_height_px, :visible_start_at, :visible_end_at,
      :visible_start_label, :visible_end_label,
      :continues_from_previous_day, :continues_into_next_day,
      keyword_init: true
    )

    def initialize(consultations:, day_start:, day_end:)
      @consultations = consultations
      @day_start = day_start
      @day_end = day_end
    end

    def items
      @items ||= begin
        entries = build_entries
        assign_lanes(entries)
        entries.map do |entry|
          Item.new(
            consultation: entry.fetch(:consultation),
            start_px: entry.fetch(:visual_start).round(2),
            height_px: (entry.fetch(:visual_end) - entry.fetch(:visual_start)).round(2),
            lane: entry.fetch(:lane),
            lanes: entry.fetch(:lanes),
            real_start_px: entry.fetch(:real_start_px).round(2),
            real_height_px: entry.fetch(:real_height_px).round(2),
            visible_start_at: entry.fetch(:visible_start_at),
            visible_end_at: entry.fetch(:visible_end_at),
            visible_start_label: entry.fetch(:visible_start_label),
            visible_end_label: entry.fetch(:visible_end_label),
            continues_from_previous_day: entry.fetch(:continues_from_previous_day),
            continues_into_next_day: entry.fetch(:continues_into_next_day)
          )
        end
      end
    end

    def max_lanes
      [items.map(&:lanes).max || 0, 1].max
    end

    private

    def build_entries
      @consultations.filter_map do |consultation|
        actual_start = [consultation.start_time, @day_start].max
        actual_end = [consultation.end_time, @day_end].min
        next unless actual_start < actual_end

        start_minute = (actual_start - @day_start) / 60.0
        end_minute = (actual_end - @day_start) / 60.0

        # A very short event must remain readable and clickable. Clamp its
        # visual card within the 24-hour canvas, without changing real times.
        real_start_px = start_minute * HOUR_HEIGHT_PX / 60.0
        real_height_px = (end_minute - start_minute) * HOUR_HEIGHT_PX / 60.0
        height_px = [real_height_px, MIN_CARD_HEIGHT_PX].max
        visual_start = [real_start_px, DAY_HEIGHT_PX - height_px].min
        visual_end = visual_start + height_px

        {
          consultation: consultation,
          visual_start: visual_start,
          visual_end: visual_end,
          real_start_px: real_start_px,
          real_height_px: real_height_px,
          visible_start_at: actual_start,
          visible_end_at: actual_end,
          visible_start_label: actual_start == @day_start ? "00:00" : actual_start.in_time_zone.strftime("%H:%M"),
          visible_end_label: actual_end == @day_end ? "24:00" : actual_end.in_time_zone.strftime("%H:%M"),
          continues_from_previous_day: consultation.start_time < @day_start,
          continues_into_next_day: consultation.end_time > @day_end
        }
      end.sort_by { |entry| [entry.fetch(:visual_start), entry.fetch(:consultation).id] }
    end

    def assign_lanes(entries)
      group = []
      group_end = -1

      entries.each do |entry|
        if group.any? && entry.fetch(:visual_start) >= group_end
          assign_lanes_to_group(group)
          group = []
        end

        group << entry
        group_end = group.map { |item| item.fetch(:visual_end) }.max
      end

      assign_lanes_to_group(group) if group.any?
    end

    def assign_lanes_to_group(group)
      lane_end_times = []

      group.each do |entry|
        lane = lane_end_times.index { |end_at| end_at <= entry.fetch(:visual_start) }
        lane ||= lane_end_times.length
        lane_end_times[lane] = entry.fetch(:visual_end)
        entry[:lane] = lane
      end

      lanes = lane_end_times.length
      group.each { |entry| entry[:lanes] = lanes }
    end
  end
end
