class OwnerCapabilitiesController < ApplicationController
  before_action :require_owner!
  before_action :load_profile
  before_action :require_approved_snapshot!

  def index
    @capabilities = @profile.professional_capabilities.where(snapshot_version: @snapshot.version).order(:domain)
    @corrections = @profile.professional_capability_corrections.index_by(&:domain)
    @suggestion = @profile.fresh_ai_suggestion? ? @profile.ai_suggestion : {}
    @ai_enabled = OwnerIntelligence::Grok.enabled?
  end

  def update
    domain = params[:capability_key].to_s
    permitted = params.require(:capability).permit(:delivery_mode, :experience_claim, :willingness, :conditions)
    @profile.with_lock do
      baseline = @profile.professional_capabilities.find_by!(snapshot_version: @snapshot.version, domain: domain)
      draft = @profile.professional_capability_corrections.find_or_initialize_by(domain: domain)
      draft.assign_attributes(
        base_snapshot_version: @snapshot.version,
        delivery_mode: permitted.fetch(:delivery_mode),
        experience_claim: permitted.fetch(:experience_claim),
        willingness: permitted.fetch(:willingness),
        conditions: permitted[:conditions].to_s.strip
      )
      if draft.delivery_mode == baseline.delivery_mode &&
         draft.experience_claim == baseline.experience_claim &&
         draft.willingness == baseline.willingness &&
         draft.conditions == baseline.conditions.to_s
        draft.destroy! if draft.persisted?
      else
        draft.save!
      end
      @profile.update!(onboarding_state: "draft") if @profile.professional_capability_corrections.exists?
    end
    redirect_to owner_capabilities_path(anchor: "cap-#{domain}"), notice: t("capability_review.saved")
  rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing, KeyError
    redirect_to owner_capabilities_path, alert: t("capability_review.invalid")
  end

  def discard
    @profile.with_lock do
      draft = @profile.professional_capability_corrections.find_by!(domain: params[:capability_key].to_s)
      draft.destroy!
      @profile.update!(onboarding_state: "approved") if
        @profile.professional_capability_corrections.none? && interview_unchanged?
    end
    redirect_to owner_capabilities_path, notice: t("capability_review.discarded")
  end

  def suggest
    return redirect_to(owner_capabilities_path, alert: t("capability_review.consent")) unless params[:ai_consent] == "1"
    OwnerIntelligence::Grok.new(@profile).suggest!
    redirect_to owner_capabilities_path(anchor: "cap-approve"), notice: t("capability_review.ai_ready")
  rescue OwnerIntelligence::Grok::Unavailable
    redirect_to owner_capabilities_path, alert: t("capability_review.ai_unavailable")
  end

  def approve
    return redirect_to(owner_capabilities_path, alert: t("capability_review.confirm")) unless params[:confirm] == "1"
    input = params.require(:profile).permit(:headline, :private_summary, :public_summary)
    headline = input[:headline].to_s.strip
    private_summary = input[:private_summary].to_s.strip
    public_summary = input[:public_summary].to_s.strip
    unless headline.length.between?(5, 160) && private_summary.length.between?(10, 1500) &&
           public_summary.length <= 1000
      return redirect_to owner_capabilities_path(anchor: "cap-approve"), alert: t("capability_review.invalid_summary")
    end
    OwnerIntelligence::CapabilityRevision.approve!(
      profile: @profile, base_version: params[:base_version],
      headline: headline, private_summary: private_summary,
      public_summary: public_summary
    )
    redirect_to owner_practice_path, notice: t("capability_review.approved")
  rescue ActiveRecord::RecordInvalid, OwnerIntelligence::CapabilityRevision::Invalid,
         OwnerIntelligence::CapabilityRevision::Stale, ActionController::ParameterMissing
    redirect_to owner_capabilities_path, alert: t("capability_review.stale")
  end

  private

  def require_owner!
    redirect_to sign_in_path, alert: t("owner_setup.owner_only") unless owner_signed_in?
  end

  def load_profile
    @profile = current_user.owner_workspace&.professional_profile
  end

  def require_approved_snapshot!
    @snapshot = @profile&.approved_snapshot
    redirect_to owner_setup_path, alert: t("capability_review.need_profile") unless @snapshot
  end

  def interview_unchanged?
    original = @snapshot.payload.fetch("interview_answers")
    current = OwnerIntelligence::Catalog::KEYS.to_h do |key|
      [key, @profile.owner_interview_answers.find_by(section_key: key)&.snapshot]
    end
    original == current
  end
end
