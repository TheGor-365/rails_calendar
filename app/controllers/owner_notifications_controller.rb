# Workspace-scoped notifications built from immutable ActivityEvent records.
# No GET endpoint marks notifications as viewed.
class OwnerNotificationsController < ApplicationController
  before_action :require_owner!

  def index
    @filter = %w[all unread].include?(params[:filter]) ? params[:filter] : "unread"
    @unread_count = Activity::Inbox.unread_for(owner: current_user).count
    scope = @filter == "unread" ? Activity::Inbox.unread_for(owner: current_user) :
      current_user.owner_workspace.activity_events
    @events = scope.order(occurred_at: :desc, id: :desc).limit(100).to_a
    @read_ids = ActivityEventRead.where(owner_user_id: current_user.id,
      activity_event_id: @events.map(&:id)).pluck(:activity_event_id).to_set
    response.headers["Cache-Control"] = "private, no-store"
  end

  def read
    event = current_user.owner_workspace.activity_events.find_by(id: params[:id])
    return head :not_found unless event

    Activity::Inbox.mark_read!(owner: current_user, event: event)
    redirect_to Activity::Presenter.display(event)[:path], status: :see_other, flash: { wa_dialog_outcome: "advance" }
  end

  def read_all
    Activity::Inbox.mark_all_read!(owner: current_user)
    redirect_to owner_notifications_path, notice: t("notifications.all_read"), status: :see_other, flash: { wa_dialog_outcome: "replace" }
  end

  private

  def require_owner!
    head :not_found unless owner_signed_in? && current_user.owner_workspace
  end
end
