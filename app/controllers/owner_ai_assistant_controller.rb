class OwnerAiAssistantController < ApplicationController
  before_action :require_owner!
  before_action :load_context

  def show
    @operation = OwnerAi::OperationRegistry.fetch(params[:operation]) ? params[:operation] : "service_copy"
    @entry = @profile&.ai_spend_entries&.where(
      operation: OwnerAi::Composer::VERSION, status: "settled"
    )&.find_by(id: params[:entry_id])
    @spend = AiSpendLedger.spend_summary
    @ai_enabled = OwnerIntelligence::Grok.enabled?
  end

  def create
    operation = params[:operation].to_s
    return redirect_to owner_ai_assistant_path, alert: t("owner_ai_assistant.invalid_operation") unless
      OwnerAi::OperationRegistry.fetch(operation)
    return redirect_to owner_ai_assistant_path(operation: operation),
                       alert: t("owner_ai_assistant.consent_required") unless params[:paid_consent] == "1"

    entry = OwnerAi::Composer.new(workspace: @workspace).generate!(
      operation: operation, brief: params[:brief]
    )
    redirect_to owner_ai_assistant_path(entry_id: entry.id, operation: operation),
                notice: t("owner_ai_assistant.draft_ready")
  rescue OwnerAi::Composer::Unavailable
    redirect_to owner_ai_assistant_path(operation: operation),
                alert: t("owner_ai_assistant.unavailable")
  end

  private

  def require_owner!
    redirect_to sign_in_path, alert: t("owner_setup.owner_only") unless owner_signed_in?
  end

  def load_context
    return unless owner_signed_in?

    @workspace = current_user.owner_workspace || current_user.create_owner_workspace!
    @profile = @workspace.professional_profile
  end
end
