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
end
