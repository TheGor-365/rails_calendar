# Private owner dashboard; future clients require a separate tenant-scoped implementation.
class WorkspaceController < ApplicationController
  before_action :require_owner_access!

  def home
    @upcoming = Consultation.where("end_time > ?", Time.current).order(:start_time, :id).limit(5)
    @upcoming_count = Consultation.where("end_time > ?", Time.current).count
    owned = ProjectIntake.where(workspace_id: current_user.owner_workspace&.id)
    owned = owned.or(ProjectIntake.where(workspace_id: nil)) if User.where(role: "owner").count == 1
    @intake_count = owned.count
    @review_count = owned.where(status: "draft_spec").count
    @recent_intakes = owned.order(created_at: :desc, id: :desc).limit(5)
    @practice_profile = current_user.owner_workspace&.professional_profile
    @outgoing_invitations = current_user.owner_workspace.client_request_invitations
      .includes(:project_intake).order(created_at: :desc, id: :desc).limit(8)
    @outgoing_count = current_user.owner_workspace.client_request_invitations.count
  end

  private

  def require_owner_access!
    return if owner_signed_in?
    # Legacy admin cookies cannot authorize these unscoped owner reports.
    redirect_to sign_in_path, alert: "Owner sign-in required"
  end
end
