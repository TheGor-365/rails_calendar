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
      @intake.errors.add(:base, "Consent to the fictional-data demo is required")
    end

    if @intake.errors.empty? && @intake.save
      session[:project_intake_id] = @intake.id
      @intake.intake_messages.create!(
        role: "assistant",
        body: "Describe your audience, the site's purpose, and the main action visitors should take."
      )
      redirect_to project_intake_path(@intake), notice: "Demo request started"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    prepare_show
  end

  def reply
    unless @intake.status == "interviewing" && @intake.client_message_count < ProjectIntake::MAX_CLIENT_MESSAGES
      return redirect_to project_intake_path(@intake), alert: "Interview is closed or has reached its limit"
    end

    message = @intake.intake_messages.new(role: "client", body: params[:answer].to_s.strip)
    unless message.save
      @message_errors = message.errors.full_messages
      prepare_show
      return render :show, status: :unprocessable_entity
    end

    # All API calls require explicitly configured server-side credentials.
    # Public demo is disabled by default; global AI daily quota is database-backed.
    answer, source = Intake::Grok.new(@intake).interview_question
    @intake.intake_messages.create!(role: "assistant", body: answer)
    redirect_to project_intake_path(@intake),
                notice: (source == "grok" ? "Grok question generated" : "Demo question generated without API charge")
  end

  def acknowledge
    spec = @intake.latest_spec
    return head :conflict unless spec&.approved?

    spec.update!(client_reviewed_at: Time.current) if spec.client_reviewed_at.nil?
    @intake.update!(status: "client_reviewed")
    redirect_to project_intake_path(@intake), notice: "Demo review recorded (not a contract or final acceptance)"
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
    @latest_spec = @intake.latest_spec
    @milestones = @intake.project_milestones.order(:position).to_a
    @visible_month = begin
      value = params[:start_date].present? ? Date.iso8601(params[:start_date].to_s) : (@milestones.first&.start_on || Date.current)
      value.year.between?(2000, 2100) ? value : Date.current
    rescue Date::Error
      @milestones.first&.start_on || Date.current
    end
  end
end
