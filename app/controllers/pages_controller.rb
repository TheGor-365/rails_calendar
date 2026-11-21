class PagesController < ApplicationController
  before_action :require_calendar_read_access!, only: %i[day hour]
  def home
    # Keep legacy calendar links and owner workflow unchanged. Only in
    # production do anonymous visitors get the PII-free service showcase.
    # No Consultation or ProjectIntake query runs on this branch.
    if Rails.env.production? && !admin_signed_in?
      return render "marketing/index", layout: "marketing"
    end

    require_calendar_read_access!
    return if performed?

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

    @month_invitations = owner_signed_in? ? current_user.owner_workspace.client_request_invitations
      .where(created_at: from...through).order(created_at: :desc).limit(100) : []
    @month_activity = owner_signed_in? ? Calendar::OwnerActivity.between(
      workspace: current_user.owner_workspace, from: from, through: through
    ) : []
    @month_activity_by_day = @month_activity.group_by { |item| item[:created_at].in_time_zone.to_date }

    @consultations_by_day = (first_visible_day..last_visible_day).to_h do |date|
      day_start = Time.zone.local(date.year, date.month, date.day)
      day_end = day_start + 1.day
      [date, @consultations.select { |event| event.start_time < day_end && event.end_time > day_start }]
    end

    # Mobile month view exposes the same day and event destinations as desktop.
    # The narrow seven-column grid is an overview; event links live in a
    # chronological agenda below it, not off-screen in a wide table.
    @month_days_with_events = @consultations_by_day.select do |date, events|
      date.year == calendar_date.year && date.month == calendar_date.month &&
        (events.any? || @month_activity_by_day.fetch(date, []).any?)
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
    @day_invitations = owner_signed_in? ? current_user.owner_workspace.client_request_invitations
      .where(created_at: day_start...day_end).order(created_at: :desc) : []
    workspace = current_user.owner_workspace if owner_signed_in?
    @day_activity = workspace ? Calendar::OwnerActivity.between(
      workspace: workspace, from: day_start, through: day_end
    ) : []
    @day_activity_by_hour = @day_activity.group_by { |item| item[:created_at].in_time_zone.hour }
    @day_total = @consultations.size + @day_activity.size
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
        consultation_count: @consultations.count do |consultation|
          consultation.start_time < slot_end && consultation.end_time > slot_start
        end,
        activity_count: @day_activity_by_hour.fetch(hour, []).size
      }.tap { |slot| slot[:count] = slot[:consultation_count] + slot[:activity_count] }
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
    workspace = current_user.owner_workspace if owner_signed_in?
    @hour_activity = workspace ? Calendar::OwnerActivity.between(
      workspace: workspace, from: @hour_start, through: @hour_end
    ) : []
    @hour_total = @consultations.size + @hour_activity.size
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
