class PagesController < ApplicationController
  def home
    requested_date = params[:start_date].presence
    calendar_date = requested_date ? Date.iso8601(requested_date) : Time.zone.today

    first_visible_day = calendar_date.beginning_of_month.beginning_of_week
    last_visible_day = calendar_date.end_of_month.end_of_week

    @consultations = Consultation.where(
      start_time: first_visible_day.beginning_of_day..last_visible_day.end_of_day
    )
  rescue Date::Error, TypeError
    redirect_to root_path, alert: "Invalid calendar date"
  end

  # Public 24-hour agenda. Admin-only write operations stay in
  # ConsultationsController and are never performed by this endpoint.
  def day
    @selected_date = params[:date].present? ? Date.iso8601(params[:date]) : Time.zone.today
    unless (Consultation::MIN_SCHEDULE_YEAR..Consultation::MAX_SCHEDULE_YEAR).cover?(@selected_date.year)
      raise Date::Error, "Unsupported calendar year"
    end

    day_start = Time.zone.local(@selected_date.year, @selected_date.month, @selected_date.day)
    day_end = day_start + 1.day

    # Include events begun before midnight but extending into this date.
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
        consultations: @consultations.select do |consultation|
          consultation.start_time < slot_end && consultation.end_time > slot_start
        end
      }
    end
  rescue Date::Error, TypeError, ArgumentError
    redirect_to root_path, alert: "Invalid calendar date"
  end
end
