# Private chronological index of persisted actions, separate from client content.
class OwnerActivityEventsController < ApplicationController
  before_action :require_owner!

  def index
    @kind = ActivityEvent::KINDS.include?(params[:kind]) ? params[:kind] : "all"
    @query = params[:q].to_s.strip.slice(0, 120)
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    scope = current_user.owner_workspace.activity_events
    scope = scope.where(kind: @kind) unless @kind == "all"
    scope = scope.where("occurred_at >= ?", @from.beginning_of_day) if @from
    scope = scope.where("occurred_at < ?", @to.next_day.beginning_of_day) if @to
    scope = scope.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%") if @query.present?
    @total_count = scope.count
    @events = scope.order(occurred_at: :desc, id: :desc).limit(150).to_a
    response.headers["Cache-Control"] = "private, no-store"
  end

  def export
    event = current_user.owner_workspace.activity_events.find_by(id: params[:id])
    return head :not_found unless event
    payload = {
      event_id: event.id, key: event.event_key, type: event.kind,
      subject: { type: event.subject_type, id: event.subject_id },
      title: event.title, occurred_at: event.occurred_at.iso8601,
      metadata: event.metadata, source_path: Activity::Presenter.display(event)[:path]
    }
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data JSON.pretty_generate(payload), filename: "rails-calendar-activity-#{event.id}.txt",
      type: "text/plain; charset=utf-8", disposition: "attachment"
  end

  private

  def parse_date(value)
    return nil if value.blank?
    Date.iso8601(value.to_s)
  rescue Date::Error, ArgumentError
    nil
  end

  def require_owner!
    head :not_found unless owner_signed_in? && current_user.owner_workspace
  end
end
