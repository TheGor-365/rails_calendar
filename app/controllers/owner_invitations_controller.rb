# Owner-only fictional E2 invitation pilot. Never enabled for real customers.
class OwnerInvitationsController < ApplicationController
  before_action :require_pilot!
  before_action :require_owner!

  def index
    load_index
  end

  def create
    load_index
    raw_ids = Array(params[:service_version_ids]).reject(&:blank?)
    ids_valid = raw_ids.length <= 6 && raw_ids.uniq.length == raw_ids.length &&
      raw_ids.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) }
    @invitation = @workspace.client_request_invitations.new(proposal_params)
    raw_proposal = params[:proposal]
    raw_selections = raw_proposal.is_a?(ActionController::Parameters) ? raw_proposal[:brief_selections] : nil
    raw_decisions = raw_proposal.is_a?(ActionController::Parameters) ? raw_proposal[:brief_decisions] : nil
    selections = raw_selections.respond_to?(:to_unsafe_h) ? raw_selections.to_unsafe_h : raw_selections
    decisions = raw_decisions.respond_to?(:to_unsafe_h) ? raw_decisions.to_unsafe_h : raw_decisions
    selections ||= {}
    decisions ||= {}
    @invitation.brief_selections = InvitationBriefTaxonomy.valid?(selections) ? selections : { "invalid" => ["invalid"] }
    @invitation.brief_decisions = InvitationBriefTaxonomy.valid_decisions?(decisions) ? decisions : { "invalid" => "invalid" }
    @invitation.brief_notes = raw_proposal[:brief_notes].to_s.strip.slice(0, 351) if raw_proposal.is_a?(ActionController::Parameters)
    @invitation.service_version_ids = ids_valid ? raw_ids.map(&:to_i) : [-1]
    @invitation.expires_at = ClientRequestInvitation::TTL.from_now
    token = SecureRandom.hex(32) # 256-bit bearer secret, never persisted.
    @invitation.token_digest = ClientRequestInvitation.digest_for(token)

    if @invitation.save
      flash[:issued_invitation_url] = client_invitation_url(anchor: "token=#{token}")
      redirect_to owner_invitations_path, notice: I18n.t("e2.invitation_issued")
    else
      render :index, status: :unprocessable_entity
    end
  end

  # E2.2: a real, journalled provider draft for this page. No changes are
  # applied to the invitation, and no cost is incurred without a fresh consent.
  # Fetch callers render this result in-place for an explicit human review.
  def ai_draft
    @workspace = current_user.owner_workspace
    response.headers["Cache-Control"] = "no-store"
    operation = params[:operation].to_s
    unless OwnerAi::PageActionRegistry.allowed?(:invitation, operation)
      return render json: { error: "unsupported_operation" }, status: :unprocessable_entity
    end
    unless params[:paid_consent] == "1"
      return render json: { error: "consent_required" }, status: :unprocessable_entity
    end

    title = params[:seed_title].to_s.strip
    goal = params[:seed_goal].to_s.strip
    selections = params[:brief_selections]
    selections = selections.to_unsafe_h if selections.respond_to?(:to_unsafe_h)
    selections ||= {}
    unless title.length.between?(5, 120) && goal.length.between?(10, 1200) &&
           InvitationBriefTaxonomy.valid?(selections)
      return render json: { error: "invalid_brief" }, status: :unprocessable_entity
    end

    # Only user-approved form facts are projected into the paid provider call;
    # never pass session cookies, private files or other clients' content.
    plain = InvitationBriefTaxonomy.sections.flat_map do |group, allowed_keys|
      keys = Array(selections[group]) & allowed_keys
      keys.empty? ? [] : ["#{group}: #{keys.join(", ")}"]
    end
    ai_input = [
      "Fictional preliminary invitation only. Do not claim a contract or promise cost.",
      "Owner task: #{title}",
      "Owner's reviewed brief: #{goal}",
      *plain
    ].join("\n")
    if ai_input.length > 1200
      return render json: { error: "brief_too_long" }, status: :unprocessable_entity
    end

    entry = OwnerAi::Composer.new(workspace: @workspace).generate!(
      operation: operation, brief: ai_input
    )
    result = entry.result
    render json: {
      id: entry.id, heading: result["heading"], draft: result["draft"],
      questions: result["questions"], cautions: result["cautions"],
      next_step: result["next_step"],
      review_url: owner_ai_assistant_path(entry_id: entry.id, operation: operation)
    }, status: :ok
  rescue OwnerAi::Composer::Unavailable
    render json: { error: "provider_unavailable" }, status: :service_unavailable
  end

  def revoke
    invite = current_user.owner_workspace&.client_request_invitations&.find_by(id: params[:id])
    return head :not_found unless invite
    outcome = invite.with_lock do
      if invite.claimed_at.present?
        :claimed
      else
        invite.update!(revoked_at: Time.current) unless invite.revoked_at.present?
        :revoked
      end
    end
    return head :conflict if outcome == :claimed
    redirect_to owner_invitations_path, notice: I18n.t("e2.revoked")
  end

  private

  def require_pilot!
    head :not_found unless ClientRequestPilot.enabled?(request: request)
  end

  def require_owner!
    return redirect_to sign_in_path unless owner_signed_in?
    head :not_found unless current_user.owner_workspace
  end

  def load_index
    @workspace = current_user.owner_workspace
    @invitations = @workspace.client_request_invitations.order(created_at: :desc).limit(50)
    @offerings = @workspace.service_offerings.where.not(published_version_id: nil)
      .includes(:published_version).order(:position, :id)
  end

  def proposal_params
    params.require(:proposal).permit(:seed_title, :seed_goal, :seed_project_type)
  end
end
