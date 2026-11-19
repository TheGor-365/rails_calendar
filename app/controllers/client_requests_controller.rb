# Two-account LOCAL proof of concept; never accepts real client data.
# This controller is deliberately separate from legacy owner-only quiz & intakes.
class ClientRequestsController < ApplicationController
  before_action :require_local_pilot!
  before_action :require_verified_client!
  before_action :set_owned_request!, only: %i[show review reply edit update submit]

  before_action :set_invitation_draft!, only: %i[edit update submit]

  # E2: an owner-authored seed remains suggested until the verified client
  # edits and deliberately submits this one canonical ProjectIntake.
  def edit
  end

  def update
    decisions = params[:fact_review]
    decisions = decisions.is_a?(ActionController::Parameters) ?
      decisions.permit(*ClientRequestInvitation::FACT_KEYS).to_h : {}
    unless ClientRequestInvitation::FACT_KEYS.all? { |key|
      ClientRequestInvitation::FACT_STATES.include?(decisions[key])
    }
      @intake.errors.add(:base, I18n.t("e2.review_required"))
      return render :edit, status: :unprocessable_entity
    end

    raw_brief = params[:brief]
    prior_brief = @intake.latest_brief_revision
    raw_selections = raw_brief.is_a?(ActionController::Parameters) ? raw_brief[:selections] : nil
    raw_decisions = raw_brief.is_a?(ActionController::Parameters) ? raw_brief[:decisions] : nil
    selections = raw_selections.respond_to?(:to_unsafe_h) ? raw_selections.to_unsafe_h : raw_selections
    brief_decisions = raw_decisions.respond_to?(:to_unsafe_h) ? raw_decisions.to_unsafe_h : raw_decisions
    selections ||= raw_brief.nil? ? (prior_brief&.selections || {}) : {}
    brief_decisions ||= raw_brief.nil? ? (prior_brief&.decisions || {}) : {}
    unless InvitationBriefTaxonomy.valid?(selections) && InvitationBriefTaxonomy.valid_decisions?(brief_decisions)
      @intake.errors.add(:base, I18n.t("e2_client_brief.invalid"))
      return render :edit, status: :unprocessable_entity
    end
    brief_notes = raw_brief.is_a?(ActionController::Parameters) ? raw_brief[:notes].to_s.strip : prior_brief&.notes.to_s
    if brief_notes.length > 350
      @intake.errors.add(:base, I18n.t("e2_client_brief.long_notes"))
      return render :edit, status: :unprocessable_entity
    end

    saved = @invitation.with_lock do
      next false if @invitation.reload.submitted_at.present?
      @intake.assign_attributes(request_params)
      next false unless @intake.valid? && @intake.goal.length <= 1200
      @intake.save!
      @invitation.update!(client_fact_reviews: decisions)
      previous = @intake.intake_brief_revisions.order(version: :desc).first
      unless previous && previous.selections == selections && previous.decisions == brief_decisions && previous.notes.to_s == brief_notes
        @intake.intake_brief_revisions.create!(
          version: (previous&.version || 0) + 1,
          author_role: "client", selections: selections,
          decisions: brief_decisions, notes: brief_notes.presence
        )
      end
      true
    end
    if saved
      redirect_to edit_client_request_path(@intake), notice: I18n.t("e2.saved_notice"), status: :see_other
    else
      @intake.errors.add(:base, I18n.t("e2.already_submitted")) if @invitation.submitted_at.present?
      render :edit, status: :unprocessable_entity
    end
  end

  def submit
    result = @invitation.with_lock do
      if @invitation.submitted_at.present?
        :already
      elsif !ClientRequestInvitation::FACT_KEYS.all? { |key|
        %w[confirmed unknown].include?(@invitation.fact_state(key))
      }
        :unreviewed
      elsif @intake.reload.valid? && @intake.goal.length <= 1200
        @intake.intake_messages.create!(role: "client", body: @intake.goal)
        @intake.intake_messages.create!(role: "assistant", body: I18n.t("client_requests.received_prompt"))
        @invitation.update!(submitted_at: Time.current)
        :submitted
      else
        :invalid
      end
    end
    if %i[invalid unreviewed].include?(result)
      @intake.errors.add(:base, I18n.t("e2.review_required")) if result == :unreviewed
      return render :edit, status: :unprocessable_entity
    end
    redirect_to client_request_path(@intake), notice: I18n.t("e2.submitted_notice"), status: :see_other
  end

  def new
    load_published_services
    @intake = current_user.client_project_intakes.new
    @selected_service_version_ids = []
  end

  def create
    load_published_services
    @selected_service_version_ids = Array(params[:service_version_ids]).reject(&:blank?).map(&:to_s)
    @intake = current_user.client_project_intakes.new(request_params)
    ids = @selected_service_version_ids
    valid_ids = ids.size <= 6 && ids.uniq.size == ids.size && ids.all? { |id| id.match?(/\A[1-9]\d*\z/) }
    versions = if valid_ids && ids.any?
      ServiceOfferingVersion.joins(:service_offering)
        .where(id: ids)
        .where("service_offerings.published_version_id = service_offering_versions.id")
        .includes(:service_offering).to_a
    else
      []
    end

    service_error = nil
    if !valid_ids || versions.size != ids.size || versions.map { |v| v.service_offering.workspace_id }.uniq.size > 1
      service_error = "client_requests.invalid_services"
    else
      chosen_ws = versions.first&.service_offering&.workspace
      if chosen_ws.nil?
        public_workspace_ids = @public_offerings.map(&:workspace_id).uniq
        requested_ws = params[:selected_workspace_id].to_s
        chosen_ws = if public_workspace_ids.size == 1
          Workspace.find_by(id: public_workspace_ids.first)
        elsif public_workspace_ids.size > 1 && requested_ws.match?(/\A[1-9]\d*\z/) &&
              public_workspace_ids.include?(requested_ws.to_i)
          Workspace.find_by(id: requested_ws)
        end
        if public_workspace_ids.size > 1 && chosen_ws.nil?
          service_error = "client_requests.choose_specialist"
        end
      end
      @intake.workspace = chosen_ws
      if versions.any?
        @intake.project_type = versions.first.project_category if @intake.project_type.blank?
        @intake.title = versions.first.title.truncate(120) if @intake.title.blank?
        @intake.goal = I18n.t("client_requests.initial_goal",
                              services: versions.map(&:title).join("; ").truncate(800)) if @intake.goal.blank?
      end
    end

    @intake.title = @intake.title.to_s.strip
    @intake.goal = @intake.goal.to_s.strip
    @intake.demo_consent_at = Time.current if params[:demo_consent] == "1"
    @intake.valid?
    @intake.errors.add(:base, I18n.t(service_error)) if service_error
    @intake.errors.add(:base, I18n.t("client_requests.consent_required")) unless params[:demo_consent] == "1"
    @intake.errors.add(:goal, I18n.t("client_requests.goal_limit")) if @intake.goal.length > 1200
    return render :new, status: :unprocessable_entity if @intake.errors.any?

    ProjectIntake.transaction do
      @intake.save!
      versions.each do |version|
        @intake.intake_service_selections.create!(service_offering_version: version)
      end
      @intake.intake_messages.create!(role: "client", body: @intake.goal)
      @intake.intake_messages.create!(role: "assistant", body: I18n.t("client_requests.received_prompt"))
    end
    redirect_to client_request_path(@intake), notice: I18n.t("client_requests.created")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def show
    load_details
  end

  # Local fictional clarification only; not a new offer, contract, spec approval,
  # or invocation of an AI provider. Enforces account ownership in set_owned_request!.
  def reply
    invitation = @intake.client_request_invitation
    if invitation && invitation.submitted_at.nil?
      return redirect_to edit_client_request_path(@intake), status: :see_other
    end
    raw_key = params[:submission_key]
    token = raw_key.is_a?(String) ? raw_key : ""
    raw_body = params[:reply_body]
    @reply_body = raw_body.is_a?(String) ? raw_body.strip : ""
    @reply_submission_key = token if token.match?(/\A[0-9a-f]{32}\z/)

    if @reply_submission_key.nil?
      @reply_error = I18n.t("client_requests.reply_invalid_request")
    elsif @reply_body.blank?
      @reply_error = I18n.t("client_requests.reply_required")
    elsif @reply_body.length > 1200
      @reply_error = I18n.t("client_requests.reply_too_long")
    end

    if @reply_error
      load_details
      return render :show, status: :unprocessable_entity
    end

    # A row lock serializes simultaneous submits for this particular intake.
    # DB uniqueness on (intake, token) remains the definitive replay guard.
    outcome = @intake.with_lock do
      if @intake.intake_messages.exists?(role: "client", client_submission_key: token)
        :duplicate
      elsif @intake.client_message_count >= ProjectIntake::MAX_CLIENT_MESSAGES
        :limit
      else
        @intake.intake_messages.create!(
          role: "client", body: @reply_body, client_submission_key: token
        )
        :created
      end
    end

    case outcome
    when :created
      redirect_to client_request_path(@intake),
                  notice: I18n.t("client_requests.reply_saved"), status: :see_other
    when :duplicate
      redirect_to client_request_path(@intake),
                  notice: I18n.t("client_requests.reply_duplicate"), status: :see_other
    else
      @reply_error = I18n.t("client_requests.reply_limit")
      load_details
      render :show, status: :unprocessable_entity
    end
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

  def load_published_services
    # One authoritative published pointer; no draft or unpublished versions.
    @public_offerings = ServiceOffering.where.not(published_version_id: nil)
      .includes(:published_version).order(:workspace_id, :position, :id).to_a
    @public_workspaces = Workspace.where(id: @public_offerings.map(&:workspace_id).uniq)
      .includes(:owner_user).order(:id).to_a
  end

  def load_details
    @invitation = @intake.client_request_invitation
    @selected_service_versions = @intake.selected_service_offering_versions.order(:id).to_a
    @spec = @intake.published_spec
    @milestones = @spec ? @intake.project_milestones.where(intake_spec_version_id: @spec.id).order(:position) : []
    @message_total = @intake.intake_messages.count
    @conversation = @intake.intake_messages.order(id: :desc).limit(20).reverse
    @latest_client_message = @intake.intake_messages.where(role: "client").order(id: :desc).first
    @client_turn_count = @intake.client_message_count
    @reply_submission_key ||= SecureRandom.hex(16)
  end

  def require_local_pilot!
    head :not_found unless ClientRequestPilot.enabled?(request: request)
  end

  def require_verified_client!
    redirect_to sign_in_path, alert: I18n.t("client_requests.sign_in_required") unless client_signed_in?
  end

  def set_invitation_draft!
    @invitation = ClientRequestInvitation.find_by(project_intake_id: @intake.id,
                                                    claimed_by_user_id: current_user.id)
    return head :not_found unless @invitation
    head :conflict if @invitation.submitted_at.present? && action_name != "submit"
  end

  def set_owned_request!
    @intake = current_user.client_project_intakes.find_by(id: params[:id])
    head :not_found unless @intake
  end

  def request_params
    params.require(:project_intake).permit(:title, :goal, :project_type)
  end
end
