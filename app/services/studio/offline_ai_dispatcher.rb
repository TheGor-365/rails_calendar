module Studio
  # Offline-only, synthetic-only dispatcher. Does not accept prompts/bytes,
  # instantiate provider clients, send network traffic or spend money.
  class OfflineAiDispatcher
    class Denied < StandardError; end
    VERSION = "rc037-offline-deterministic-v1"
    PROVIDERS = {
      "offline_template" => { available: true, external: false, billable: false },
      "reviewed_provider" => { available: false, external: true, billable: true }
    }.freeze

    def initialize(actor:, workspace:, intake:)
      @workspace, @intake, @actor = workspace, intake, actor
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      unless (Rails.env.test? ||
             (Rails.env.development? && ENV["RC_STUDIO_AI_OFFLINE"] == "true")) &&
             !Rails.env.production?
        raise Denied, "Offline synthetic dispatcher unavailable"
      end
      unless intake.is_a?(ProjectIntake) && intake.persisted? &&
             intake.workspace_id == workspace.id &&
             workspace.project_intakes.where(id: intake.id).exists?
        raise Denied, "Invalid scoped project"
      end
    end

    def call(purpose:, data_class: "synthetic", source_ids: [])
      @access.assert_owner!
      raise Denied, "Unsupported purpose" unless AiPolicy::PURPOSES.include?(purpose)
      raise Denied, "Sensitive or unidentified content denied" unless data_class == "synthetic"

      defaults = @workspace.studio_ai_policies.find_by(project_intake_id: nil)
      override = @workspace.studio_ai_policies.find_by(project_intake_id: @intake.id)
      unless defaults && defaults.mode != "off" && defaults.purposes.include?(purpose)
        raise Denied, "Workspace policy disallows AI assistance"
      end
      if override && (override.mode == "off" || !override.purposes.include?(purpose))
        raise Denied, "Project policy restricts AI assistance"
      end

      selected = OfflineSourceSelector.new(
        actor: @actor, workspace: @workspace, intake: @intake
      ).select!(source_ids: source_ids)

      requested = if defaults.mode == "reviewed_provider" &&
                     (override.nil? || override.mode == "reviewed_provider")
                    "reviewed_provider_unavailable"
                  else
                    "offline"
                  end
      result = {
        schema_version: VERSION,
        template_version: OfflineTemplateRegistry::VERSION,
        status: "needs_human_review",
        purpose: purpose,
        mode_executed: "offline",
        provider_requested: requested,
        provider_executed: "offline_template",
        input_classification: "UNVERIFIED_SYNTHETIC_ONLY",
        source_metadata_count: selected.size,
        text: OfflineTemplateRegistry.render!(purpose: purpose),
        external_calls: 0,
        tokens_billed: 0,
        billable_usd: 0,
        auto_approved: false
      }
      OfflineOutputContract.validate!(result)
    end
  end
end
