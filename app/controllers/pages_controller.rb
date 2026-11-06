class PagesController < ApplicationController
  def home
    requested_date = params[:start_date].presence
    calendar_date = requested_date ? Date.iso8601(requested_date) : Time.zone.today

    first_visible_day = calendar_date.beginning_of_month.beginning_of_week
    last_visible_day = calendar_date.end_of_month.end_of_week
    from = Time.zone.local(first_visible_day.year, first_visible_day.month, first_visible_day.day)
    last_date = last_visible_day.next_day
    through = Time.zone.local(last_date.year, last_date.month, last_date.day)

    # Fetch overlaps, not just sessions beginning this month. Otherwise a
    # cross-midnight consultation disappears from the next month's first cell.
    @consultations = Consultation.where(
      "start_time < :through AND end_time > :from",
      from: from, through: through
    ).order(:start_time, :id).to_a

    @consultations_by_day = (first_visible_day..last_visible_day).to_h do |date|
      day_start = Time.zone.local(date.year, date.month, date.day)
      day_end = day_start + 1.day
      [date, @consultations.select { |event| event.start_time < day_end && event.end_time > day_start }]
    end
  rescue Date::Error, TypeError, ArgumentError
    redirect_to root_path, alert: "Invalid calendar date"
  end

  # Public 24-hour agenda. All write operations remain admin-only.
  def day
    @selected_date = params[:date].present? ? Date.iso8601(params[:date]) : Time.zone.today
    unless (Consultation::MIN_SCHEDULE_YEAR..Consultation::MAX_SCHEDULE_YEAR).cover?(@selected_date.year)
      raise Date::Error, "Unsupported calendar year"
    end

    day_start = Time.zone.local(@selected_date.year, @selected_date.month, @selected_date.day)
    day_end = day_start + 1.day

    @consultations = Consultation.where(
      "start_time < :day_end AND end_time > :day_start",
      day_start: day_start,
      day_end: day_end
    ).order(:start_time, :id).to_a

    @hour_slots = (0..23).map do |hour|
      slot_start = Time.zone.local(@selected_date.year, @selected_date.month, @selected_date.day, hour)
      slot_end = slot_start + 1.hour

      {
        start_time: slot_start,
        consultations: @consultations.select do |event|
          event.start_time < slot_end && event.end_time > slot_start
        end
      }
    end
  rescue Date::Error, TypeError, ArgumentError
    redirect_to root_path, alert: "Invalid calendar date"
  end
end
