module Studio
  # RC-037 initial executable policy boundary: strictly deterministic
  # synthetic planning, no model SDK, network, raw source retrieval or tokens.
  class OfflineAiDispatcher
    VERSION = "studio-offline-dispatch.v1".freeze

    def initialize(actor:, workspace:, intake:)
      @actor, @workspace, @intake = actor, workspace, intake
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      authorize!
    end

    def call(purpose:, data_class:, evidence: {}, requested_mode: "offline",
             estimated_tokens: 0, estimated_usd: 0)
      authorize! # membership may have been revoked after object creation

      return denied("nonproduction_only") unless Rails.env.test? ||
        (Rails.env.development? && ENV["RC_STUDIO_SYNTHETIC_STORAGE"] == "true")
      return denied("production_disabled") if Rails.env.production?

      unless AiPolicy::PURPOSES.include?(purpose) && AiPolicy::DATA_CLASSES.include?(data_class)
        return denied("purpose_or_data_class_not_supported")
      end
      return denied("external_calls_hard_disabled") unless requested_mode == "offline" &&
        estimated_tokens == 0 && estimated_usd == 0

      policies = AiPolicy.where(workspace_id: @workspace.id,
                                project_intake_id: [nil, @intake.id]).to_a
      workspace_policy = policies.find { |policy| policy.project_intake_id.nil? }
      project_policy = policies.find { |policy| policy.project_intake_id == @intake.id }
      return denied("workspace_policy_off") unless workspace_policy&.mode == "offline"
      return denied("project_restriction") if project_policy && project_policy.mode != "offline"

      [workspace_policy, project_policy].compact.each do |policy|
        return denied("purpose_restricted") unless policy.allowed_purposes.include?(purpose)
        return denied("data_class_restricted") unless policy.allowed_data_classes.include?(data_class)
      end

      # A caller may supply only boolean evidence claims. This output is a
      # PROPOSAL, not validation, consent, source-derived fact or approval.
      plan = DocumentGenerationPlan.new.call(evidence: evidence)
      {
        schema_version: VERSION, status: "offline_proposal", reason: nil,
        provider: "none", model: "deterministic_document_plan_v1",
        external_calls: 0, tokens: 0, usd: "0.000000",
        source_bytes_accessed: false, human_review_required: true,
        production_ready: false, output: plan
      }
    end

    private

    def authorize!
      @access.assert_owner!
      unless @intake.is_a?(ProjectIntake) && @intake.persisted? &&
             @intake.workspace_id == @workspace.id && @intake.client_id.present? &&
             @workspace.clients.where(id: @intake.client_id).exists?
        raise SecurityError, "No access to this assigned project"
      end
    end

    def denied(reason)
      {
        schema_version: VERSION, status: "denied", reason: reason,
        provider: "none", external_calls: 0, tokens: 0, usd: "0.000000",
        source_bytes_accessed: false, human_review_required: true,
        production_ready: false
      }
    end
  end
end
