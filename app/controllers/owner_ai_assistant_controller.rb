class OwnerAiAssistantController < ApplicationController
  before_action :require_owner!
  before_action :load_context

  def show
    @operation = OwnerAi::OperationRegistry.fetch(params[:operation]) ? params[:operation] : "service_copy"
    @navigation_result = if params[:nav_query].is_a?(String) && params[:nav_query].present?
      OwnerAi::Navigator.search(params[:nav_query], workspace: @workspace, admin: admin_signed_in?)
    end
    @entry = owner_entries.find_by(id: params[:entry_id]) if params[:entry_id].present?
    @thread = []
    if @entry
      previous = @entry
      4.times do
        break unless previous
        @thread.unshift(previous)
        parent_id = previous.result.is_a?(Hash) && previous.result["parent_entry_id"]
        previous = parent_id.present? ? owner_entries.find_by(id: parent_id) : nil
      end
    end
    @draft_history = owner_entries.order(created_at: :desc, id: :desc).limit(12)
    @knowledge = OwnerAi::KnowledgeReadiness.new(workspace: @workspace)
    @spend = AiSpendLedger.spend_summary
    @ai_enabled = OwnerIntelligence::Grok.enabled?
    @draft_offerings = @workspace.service_offerings.includes(:versions).order(:position, :id)
      .select { |offering| offering.draft_version&.professional_context_snapshot_id == @profile&.approved_snapshot&.id }
    @context_offering = @draft_offerings.find { |offering| offering.id.to_s == params[:offering_id].to_s }
    if @entry && @entry.result["purpose"] == "service_copy"
      @selected_offering = @draft_offerings.find { |offering| offering.id.to_s == params[:offering_id].to_s }
      @selected_draft = @selected_offering&.draft_version
    end
  end

  def create
    operation = params[:operation].to_s
    return redirect_to owner_ai_assistant_path, alert: t("owner_ai_assistant.invalid_operation") unless
      OwnerAi::OperationRegistry.fetch(operation)
    return redirect_to owner_ai_assistant_path(operation: operation),
                       alert: t("owner_ai_assistant.consent_required") unless params[:paid_consent] == "1"

    parent = nil
    if params[:parent_entry_id].present?
      parent = owner_entries.find_by(id: params[:parent_entry_id])
      return redirect_to owner_ai_assistant_path(operation: operation),
                         alert: t("owner_ai_assistant.invalid_parent") unless parent
    end
    entry = OwnerAi::Composer.new(workspace: @workspace).generate!(
      operation: operation, brief: params[:brief], parent: parent
    )
    context = @workspace.service_offerings.find_by(id: params[:offering_id])
    destination = { entry_id: entry.id, operation: operation }
    destination[:offering_id] = context.id if context&.draft_version
    redirect_to owner_ai_assistant_path(destination),
                notice: t("owner_ai_assistant.draft_ready")
  rescue OwnerAi::Composer::Unavailable
    redirect_to owner_ai_assistant_path(operation: operation),
                alert: t("owner_ai_assistant.unavailable")
  end

  def apply
    entry = owner_entries.find_by(id: params[:entry_id])
    offering = @workspace.service_offerings.find_by(id: params[:offering_id])
    OwnerAi::DraftApplier.new(workspace: @workspace).apply!(
      entry: entry, offering_id: params[:offering_id],
      base_version: params[:base_version], base_digest: params[:base_digest],
      summary: params[:summary], confirmed: params[:confirmed] == "1"
    )
    redirect_to owner_service_path(offering), notice: t("owner_ai_assistant.applied_to_draft")
  rescue OwnerAi::DraftApplier::Conflict
    redirect_to owner_ai_assistant_path(entry_id: params[:entry_id], offering_id: params[:offering_id]),
                alert: t("owner_ai_assistant.apply_conflict")
  end

  def navigate
    query = params[:command].is_a?(String) ? params[:command].strip : ""
    if query.blank? || query.length > 120 || query.match?(%r{https?://|www\.|[/\\]|[<>]}i)
      return redirect_to owner_ai_assistant_path, alert: t("owner_ai_assistant.unknown_destination")
    end
    result = OwnerAi::Navigator.search(query, workspace: @workspace, admin: admin_signed_in?)
    case result.status
    when :match
      redirect_to result.target.path
    when :ambiguous
      redirect_to owner_ai_assistant_path(nav_query: query),
                  notice: t("owner_ai_assistant.navigation_choose")
    else
      redirect_to owner_ai_assistant_path(nav_query: query),
                  alert: t("owner_ai_assistant.unknown_destination")
    end
  end

  private

  def owner_entries
    @profile ? @profile.ai_spend_entries.where(operation: OwnerAi::Composer::VERSION, status: "settled") :
      AiSpendEntry.none
  end

  def require_owner!
    redirect_to sign_in_path, alert: t("owner_setup.owner_only") unless owner_signed_in?
  end

  def load_context
    return unless owner_signed_in?

    @workspace = current_user.owner_workspace || current_user.create_owner_workspace!
    @profile = @workspace.professional_profile
  end
end
