class OwnerSetupController < ApplicationController
  before_action :require_owner!
  before_action :set_professional_profile

  def show
    @answers = @profile.owner_interview_answers.index_by(&:section_key)
    key = params[:step].presence || OwnerIntelligence::Catalog::KEYS.find { |item| !@answers.key?(item) }
    return redirect_to(owner_setup_review_path) unless key
    return head :not_found unless OwnerIntelligence::Catalog::KEYS.include?(key)

    @current_key = key
    @question = OwnerIntelligence::Catalog.question(key)
    @answer = @answers[key] || @profile.owner_interview_answers.build(section_key: key)
  end

  def update
    key = params[:section_key].to_s
    return head :not_found unless OwnerIntelligence::Catalog::KEYS.include?(key)

    submitted = params.require(:owner_answer).permit(:notes, :unsure, selected_options: [])
    choices = Array(submitted[:selected_options]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    notes = submitted[:notes].to_s.strip
    unsure = submitted[:unsure] == "1"

    if choices.empty? && notes.empty? && !unsure
      return redirect_to(owner_setup_path(step: key), alert: t("owner_setup.answer_required"))
    end

    @profile.with_lock do
      answer = @profile.owner_interview_answers.find_or_initialize_by(section_key: key)
      answer.assign_attributes(selected_options: choices, notes: notes, unsure: unsure)
      if answer.new_record? || answer.changed?
        answer.revision = answer.new_record? ? 1 : answer.revision + 1
        answer.save!
        answer.owner_interview_answer_revisions.create!(
          revision: answer.revision, snapshot: answer.snapshot
        )
        # Previously approved versions remain immutable; new answers are drafts.
        @profile.update!(onboarding_state: "draft") if @profile.onboarding_state != "draft"
      end
    end

    next_index = OwnerIntelligence::Catalog::KEYS.index(key) + 1
    destination = OwnerIntelligence::Catalog::KEYS[next_index]
    redirect_to(destination ? owner_setup_path(step: destination) : owner_setup_review_path,
                notice: t("owner_setup.saved"))
  rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing
    redirect_to owner_setup_path(step: key), alert: t("owner_setup.invalid_answer")
  end

  def review
    unless @profile.interview_complete?
      return redirect_to(owner_setup_path, alert: t("owner_setup.complete_first"))
    end
    @answers = @profile.owner_interview_answers.index_by(&:section_key)
    @suggestion = @profile.fresh_ai_suggestion? ? @profile.ai_suggestion : {}
    @ai_enabled = OwnerIntelligence::Grok.enabled?
    @spend = AiSpendLedger.spend_summary
  end

  def suggest
    return redirect_to(owner_setup_path, alert: t("owner_setup.complete_first")) unless @profile.interview_complete?
    return redirect_to(owner_setup_review_path, alert: t("owner_setup.consent_required")) unless params[:ai_consent] == "1"

    OwnerIntelligence::Grok.new(@profile).suggest!
    redirect_to owner_setup_review_path, notice: t("owner_setup.ai_ready")
  rescue OwnerIntelligence::Grok::Unavailable
    redirect_to owner_setup_review_path, alert: t("owner_setup.ai_unavailable")
  end

  def approve
    return redirect_to(owner_setup_path, alert: t("owner_setup.complete_first")) unless @profile.interview_complete?
    return redirect_to(owner_setup_review_path, alert: t("owner_setup.confirm_required")) unless params[:confirmation] == "1"

    permitted = params.require(:professional_profile).permit(:headline, :private_summary, :public_summary)
    headline = permitted[:headline].to_s.strip
    private_summary = permitted[:private_summary].to_s.strip
    public_summary = permitted[:public_summary].to_s.strip
    unless headline.length.between?(5, 160) && private_summary.length.between?(10, 1500) &&
           public_summary.length <= 1000
      return redirect_to(owner_setup_review_path, alert: t("owner_setup.invalid_profile"))
    end

    @profile.with_lock do
      payload = OwnerIntelligence::Compiler.build(
        profile: @profile, headline: headline, private_summary: private_summary,
        public_summary: public_summary
      )
      version = @profile.professional_context_snapshots.maximum(:version).to_i + 1
      digest = Digest::SHA256.hexdigest(JSON.generate(payload))

      @profile.professional_context_snapshots.create!(
        version: version, payload: payload, digest: digest, approved_at: Time.current
      )
      payload.fetch("capabilities").each do |item|
        @profile.professional_capabilities.create!(
          snapshot_version: version, domain: item.fetch("domain"),
          delivery_mode: item.fetch("delivery_mode"),
          experience_claim: item.fetch("experience_claim"),
          evidence_status: item.fetch("evidence_status"),
          willingness: item.fetch("willingness"),
          privacy_scope: item.fetch("privacy_scope"),
          review_required: item.fetch("review_required"),
          conditions: item.fetch("conditions")
        )
      end
      @profile.work_policies.create!(
        snapshot_version: version,
        hard_no_go: payload.fetch("hard_no_go"),
        work_preferences: payload.fetch("work_preferences"),
        notes: @profile.owner_interview_answers.find_by(section_key: "D")&.notes.to_s
      )
      @profile.update!(headline: headline, private_summary: private_summary,
                       public_summary: public_summary, onboarding_state: "approved")
    end
    redirect_to owner_practice_path, notice: t("owner_setup.approved")
  rescue ActiveRecord::RecordInvalid, ArgumentError, ActionController::ParameterMissing
    redirect_to owner_setup_review_path, alert: t("owner_setup.invalid_profile")
  end

  def practice
    @snapshot = @profile.approved_snapshot
    @capabilities = @snapshot ? @profile.professional_capabilities.where(snapshot_version: @snapshot.version).order(:domain) : []
    @policy = @snapshot ? @profile.work_policies.find_by(snapshot_version: @snapshot.version) : nil
  end

  def cabinet
    @snapshot = @profile.approved_snapshot
    @answered_count = @profile.completed_sections
    @ai_spend = AiSpendLedger.spend_summary
    @version_count = @profile.professional_context_snapshots.count
    @open_intakes = ProjectIntake.where(status: %w[interviewing draft_spec]).count
    @upcoming_consultations = Consultation.where("start_time >= ?", Time.current).count
  end

  def ai_activity
    @entries = @profile.ai_spend_entries.order(id: :desc).limit(30)
    @spend = AiSpendLedger.spend_summary
  end

  private

  def require_owner!
    redirect_to sign_in_path, alert: t("owner_setup.owner_only") unless owner_signed_in?
  end

  def set_professional_profile
    @workspace = current_user.owner_workspace || current_user.create_owner_workspace!
    @profile = @workspace.professional_profile || @workspace.create_professional_profile!
  end
end
