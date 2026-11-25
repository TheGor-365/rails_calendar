# C2.3b6b — private observability only. No replay, mutation or AI calls.
class OwnerOutboxHealthController < ApplicationController
  before_action :require_owner!

  def index
    selected = params[:limit]
    @limit = selected.is_a?(String) && selected.match?(/\A(?:10|25|50|100)\z/) ?
      selected.to_i : 25
    @snapshot = DomainOutbox::Health.snapshot(owner: current_user)
    @candidates = DomainOutbox::Health.preview(owner: current_user, limit: @limit)
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
  end

  private

  def require_owner!
    head :not_found unless owner_signed_in? && current_user.owner_workspace
  end
end
