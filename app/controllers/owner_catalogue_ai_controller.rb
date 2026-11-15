class OwnerCatalogueAiController < ApplicationController
  before_action :require_owner!
  before_action :load_context

  def index
    @entry = @copilot.latest_review
    @recommendations = Array(@entry&.result&.dig("recommendations"))
    @ai_enabled = OwnerServices::CatalogueCopilot.enabled?
    @spend = AiSpendLedger.spend_summary
  end

  def run
    unless params[:paid_consent] == "1"
      return redirect_to owner_catalogue_ai_path, alert: t("owner_services.copilot_consent")
    end
    entry = @copilot.audit!
    redirect_to owner_catalogue_ai_path, notice: t("owner_services.copilot_completed", count: Array(entry.result["recommendations"]).length)
  rescue OwnerServices::CatalogueCopilot::Unavailable
    redirect_to owner_catalogue_ai_path, alert: t("owner_services.copilot_unavailable")
  end

  def apply
    entry = @profile.ai_spend_entries.find_by(id: params[:entry_id])
    @copilot.apply!(entry: entry, offering_id: params[:offering_id], base_digest: params[:base_digest])
    redirect_to owner_service_path(params[:offering_id]), notice: t("owner_services.copilot_draft_created")
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
