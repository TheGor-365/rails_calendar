# Private owner dashboard; future clients require a separate tenant-scoped implementation.
class WorkspaceController < ApplicationController
  before_action :require_owner_access!

  def home
    @upcoming = Consultation.where("end_time > ?", Time.current).order(:start_time, :id).limit(5)
    @upcoming_count = Consultation.where("end_time > ?", Time.current).count
    @intake_count = ProjectIntake.count
    @review_count = ProjectIntake.where(status: "draft_spec").count
    @recent_intakes = ProjectIntake.order(created_at: :desc, id: :desc).limit(5)
  end

  private

  def require_owner_access!
    return if owner_signed_in?
    # Legacy admin cookies cannot authorize these unscoped owner reports.
    redirect_to sign_in_path, alert: "Owner sign-in required"
  end
end
