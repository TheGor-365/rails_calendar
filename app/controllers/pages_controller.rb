class PagesController < ApplicationController
  def home
    requested_date = params[:start_date].presence
    calendar_date = requested_date ? Date.iso8601(requested_date) : Time.zone.today
    @displayed_month = calendar_date

    first_visible_day = calendar_date.beginning_of_month.beginning_of_week
    last_visible_day = calendar_date.end_of_month.end_of_week
    from = Time.zone.local(first_visible_day.year, first_visible_day.month, first_visible_day.day)
    last_date = last_visible_day.next_day
    through = Time.zone.local(last_date.year, last_date.month, last_date.day)

    @consultations = Consultation.where(
      "start_time < :through AND end_time > :from",
      from: from, through: through
    ).order(:start_time, :id).to_a

    @consultations_by_day = (first_visible_day..last_visible_day).to_h do |date|
      day_start = Time.zone.local(date.year, date.month, date.day)
      day_end = day_start + 1.day
      [date, @consultations.select { |event| event.start_time < day_end && event.end_time > day_start }]
    end

    # Mobile month view exposes the same day and event destinations as desktop.
    # The narrow seven-column grid is an overview; event links live in a
    # chronological agenda below it, not off-screen in a wide table.
    @month_days_with_events = @consultations_by_day.select do |date, events|
      date.year == calendar_date.year && date.month == calendar_date.month && events.any?
    end
  rescue Date::Error, TypeError, ArgumentError
    redirect_to root_path, alert: "Invalid calendar date"
  end

  # Each event is drawn ONCE in a continuous vertical 24-hour schedule.
  # Hour links remain public and admin-only writes retain controller guards.
  def day
    @selected_date = schedule_date_from(params[:date])
    day_start = Time.zone.local(@selected_date.year, @selected_date.month, @selected_date.day)
    day_end = day_start + 1.day

    @consultations = overlapping_consultations(day_start, day_end)
    @timeline = Calendar::DayEventLayout.new(
      consultations: @consultations, day_start: day_start, day_end: day_end
    )

    @hour_slots = (0..23).map do |hour|
      slot_start = Time.zone.local(@selected_date.year, @selected_date.month, @selected_date.day, hour)
      slot_end = slot_start + 1.hour

      {
        hour: hour,
        start_time: slot_start,
        end_time: slot_end,
        count: @consultations.count do |consultation|
          consultation.start_time < slot_end && consultation.end_time > slot_start
        end
      }
    end
  rescue Date::Error, TypeError, ArgumentError
    redirect_to root_path, alert: "Invalid calendar date"
  end

  # Detailed [hour, next hour) interval. Used by every clickable time cell.
  def hour
    @selected_date = schedule_date_from(params[:date])
    hour_string = params[:hour].to_s
    raise ArgumentError, "Invalid hour" unless hour_string.match?(/\A(?:[01]?\d|2[0-3])\z/)

    @selected_hour = hour_string.to_i
    @hour_start = Time.zone.local(@selected_date.year, @selected_date.month,
                                  @selected_date.day, @selected_hour)
    @hour_end = @hour_start + 1.hour
    @consultations = overlapping_consultations(@hour_start, @hour_end)
  rescue Date::Error, TypeError, ArgumentError
    redirect_to root_path, alert: "Invalid calendar interval"
  end

  private

  def schedule_date_from(value)
    date = value.present? ? Date.iso8601(value) : Time.zone.today
    unless (Consultation::MIN_SCHEDULE_YEAR..Consultation::MAX_SCHEDULE_YEAR).cover?(date.year)
      raise Date::Error, "Unsupported calendar year"
    end
    date
  end

  def overlapping_consultations(from, through)
    Consultation.where(
      "start_time < :through AND end_time > :from",
      from: from, through: through
    ).order(:start_time, :id).to_a
  end
end
