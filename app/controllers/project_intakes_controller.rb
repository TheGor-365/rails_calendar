class ProjectIntakesController < ApplicationController
  before_action :require_intake_demo!, only: %i[new create]
  before_action :set_intake, only: %i[show reply acknowledge]
  before_action :require_intake_access!, only: %i[show reply acknowledge]

  def new
    @intake = ProjectIntake.new
  end

  def create
    @intake = ProjectIntake.new(intake_params)
    if params[:demo_consent] == "1"
      @intake.demo_consent_at = Time.current
    else
      @intake.errors.add(:base, I18n.t("intake.flash_consent"))
    end

    if @intake.errors.empty? && @intake.save
      session[:project_intake_id] = @intake.id
      @intake.intake_messages.create!(
        role: "assistant",
        body: I18n.t("intake.flash_intro")
      )
      redirect_to project_intake_path(@intake), notice: I18n.t("intake.flash_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    prepare_show
  end

  def reply
    unless @intake.status == "interviewing" && @intake.client_message_count < ProjectIntake::MAX_CLIENT_MESSAGES
      return redirect_to project_intake_path(@intake), alert: I18n.t("intake.flash_interview_limit")
    end

    message = @intake.intake_messages.new(role: "client", body: params[:answer].to_s.strip)
    unless message.save
      @message_errors = message.errors.full_messages
      prepare_show
      return render :show, status: :unprocessable_entity
    end

    # At the eighth answer, finish the interview. Do not ask a ninth
    # question or spend on a Grok request the user cannot answer.
    if @intake.client_message_count >= ProjectIntake::MAX_CLIENT_MESSAGES
      @intake.intake_messages.create!(
        role: "assistant",
        body: "Interview complete. An administrator can now generate and review the proposed specification."
      )
      return redirect_to project_intake_path(@intake), notice: I18n.t("intake.flash_interview_done")
    end

    # All API calls require explicitly configured server-side credentials.
    # Public demo is disabled by default; global AI daily quota is database-backed.
    answer, source = Intake::Grok.new(@intake).interview_question
    @intake.intake_messages.create!(role: "assistant", body: answer)
    redirect_to project_intake_path(@intake),
                notice: I18n.t(source == "grok" ? "intake.flash_generated_ai" : "intake.flash_generated_template")
  end

  def acknowledge
    spec = @intake.published_spec
    return head :conflict unless spec&.approved?

    spec.update!(client_reviewed_at: Time.current) if spec.client_reviewed_at.nil?
    # A client reviewing the previous published version must not discard the
    # pending newer draft/version review state.
    @intake.update!(status: "client_reviewed") if @intake.status == "owner_approved"
    redirect_to project_intake_path(@intake), notice: I18n.t("intake.flash_review_recorded")
  end

  private

  def intake_params
    params.require(:project_intake).permit(:title, :project_type, :goal)
  end

  def set_intake
    @intake = ProjectIntake.find(params[:id])
  end

  def require_intake_demo!
    return if admin_signed_in? || ENV["RC_INTAKE_PUBLIC_DEMO"] == "true"

    redirect_to admin_login_path, alert: "Intake is restricted to a synthetic demonstration"
  end

  def require_intake_access!
    return if admin_signed_in?
    return if ENV["RC_INTAKE_PUBLIC_DEMO"] == "true" && session[:project_intake_id] == @intake.id

    head :not_found
  end

  def prepare_show
    @messages = @intake.intake_messages.order(:id).limit(20)
    @latest_spec = admin_signed_in? ? @intake.latest_spec : @intake.published_spec
    @milestones = @intake.project_milestones.order(:position).to_a
    @visible_month = begin
      value = params[:start_date].present? ? Date.iso8601(params[:start_date].to_s) : (@milestones.first&.start_on || Date.current)
      value.year.between?(2000, 2100) ? value : Date.current
    rescue Date::Error
      @milestones.first&.start_on || Date.current
    end
  end
end
