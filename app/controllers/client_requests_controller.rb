# Two-account LOCAL proof of concept; never accepts real client data.
# This controller is deliberately separate from legacy owner-only quiz & intakes.
class ClientRequestsController < ApplicationController
  before_action :require_local_pilot!
  before_action :require_verified_client!
  before_action :set_owned_request!, only: %i[show review]

  def new
    @intake = current_user.client_project_intakes.new
  end

  def create
    @intake = current_user.client_project_intakes.new(request_params)
    @intake.title = @intake.title.to_s.strip
    @intake.goal = @intake.goal.to_s.strip
    @intake.demo_consent_at = Time.current if params[:demo_consent] == "1"
    @intake.valid?
    @intake.errors.add(:base, I18n.t("client_requests.consent_required")) unless params[:demo_consent] == "1"
    @intake.errors.add(:goal, I18n.t("client_requests.goal_limit")) if @intake.goal.length > 1200
    if @intake.errors.any?
      return render :new, status: :unprocessable_entity
    end

    ProjectIntake.transaction do
      @intake.save!
      @intake.intake_messages.create!(role: "client", body: @intake.goal)
      @intake.intake_messages.create!(role: "assistant", body: I18n.t("client_requests.received_prompt"))
    end
    redirect_to client_request_path(@intake), notice: I18n.t("client_requests.created")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def show
    @spec = @intake.published_spec
    @milestones = @spec ? @intake.project_milestones.where(intake_spec_version_id: @spec.id).order(:position) : []
  end

  # Only acknowledges having read a specific owner-approved revision.
  # Not an acceptance of price, schedule, contract or final work.
  def review
    version = params[:version].to_s
    return head :unprocessable_entity unless version.match?(/\A[1-9]\d{0,8}\z/)

    outcome = @intake.with_lock do
      spec = @intake.published_spec
      if !spec || spec.version != version.to_i
        :conflict
      else
        spec.update!(client_reviewed_at: Time.current) if spec.client_reviewed_at.nil?
        @intake.update!(status: "client_reviewed") if @intake.status == "owner_approved"
        :ok
      end
    end
    return head :conflict unless outcome == :ok
    redirect_to client_request_path(@intake), notice: I18n.t("client_requests.reviewed_notice")
  end

  private

  def require_local_pilot!
    head :not_found unless ClientRequestPilot.enabled?(request: request)
  end

  def require_verified_client!
    redirect_to sign_in_path, alert: I18n.t("client_requests.sign_in_required") unless client_signed_in?
  end

  def set_owned_request!
    @intake = current_user.client_project_intakes.find_by!(id: params[:id])
  end

  def request_params
    params.require(:project_intake).permit(:title, :goal, :project_type)
  end
end
