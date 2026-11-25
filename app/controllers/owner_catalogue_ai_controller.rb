class OwnerCatalogueAiController < ApplicationController
  before_action :require_owner!
  before_action :load_context

  def index
    @entry = @copilot.latest_review
    @recommendations = Array(@entry&.result&.dig("recommendations"))
    @ai_enabled = OwnerServices::CatalogueCopilot.enabled?
    @spend = AiSpendLedger.spend_summary
    @offer_count = @workspace.service_offerings.count
    @review_filter = %w[all category copy risk ready].include?(params[:filter]) ? params[:filter] : "all"
    @filtered_recommendations = @recommendations.select do |row|
      offering = @workspace.service_offerings.find_by(id: row["offering_id"])
      current = offering && (offering.draft_version || offering.approved_version || offering.published_version)
      case @review_filter
      when "category" then current && row["project_category"] != current.project_category
      when "copy" then current && %w[title summary included_scope excluded_scope requirements_prompt].any? { |key| row[key] != current.public_send(key) }
      when "risk" then Array(row["risk_flags"]).any?
      when "ready" then @copilot.recommendation_current?(row)
      else true
      end
    end
  end

  def run
    unless params[:paid_consent] == "1"
      return redirect_to owner_catalogue_ai_path, alert: t("owner_services.copilot_consent")
    end
    entry = @copilot.audit!
    redirect_to owner_catalogue_ai_path, notice: t("owner_services.copilot_completed", count: Array(entry.result["recommendations"]).length), flash: { wa_dialog_outcome: "replace" }
  rescue OwnerServices::CatalogueCopilot::Unavailable
    redirect_to owner_catalogue_ai_path, alert: t("owner_services.copilot_unavailable")
  end

  def apply_all
    entry = @profile&.ai_spend_entries&.find_by(id: params[:entry_id])
    count = @copilot.apply_all!(entry: entry, expected_fingerprint: params[:fingerprint].to_s)
    redirect_to owner_catalogue_ai_path, notice: t("owner_services.copilot_all_drafts", count: count), flash: { wa_dialog_outcome: "replace" }
  rescue OwnerServices::CatalogueCopilot::Conflict
    redirect_to owner_catalogue_ai_path, alert: t("owner_services.copilot_stale")
  end

  def apply
    entry = @profile&.ai_spend_entries&.find_by(id: params[:entry_id])
    @copilot.apply!(entry: entry, offering_id: params[:offering_id], base_digest: params[:base_digest])
    redirect_to owner_service_path(params[:offering_id]), notice: t("owner_services.copilot_draft_created"), flash: { wa_dialog_outcome: "replace" }
  rescue OwnerServices::CatalogueCopilot::Conflict
    redirect_to owner_catalogue_ai_path, alert: t("owner_services.copilot_stale")
  end

  private

  def require_owner!
    redirect_to sign_in_path, alert: t("owner_setup.owner_only") unless owner_signed_in?
  end

  def load_context
    @workspace = current_user.owner_workspace || current_user.create_owner_workspace!
    @copilot = OwnerServices::CatalogueCopilot.new(workspace: @workspace)
    @profile = @copilot.profile
  end
end
