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
