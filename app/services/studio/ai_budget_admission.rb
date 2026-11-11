module Studio
  # Explicit zero-cost admission. No provider SDK, billing reservation, network
  # or client content. Positive stored preferences NEVER enable paid execution.
  class AiBudgetAdmission
    class Denied < StandardError; end

    def initialize(actor:, workspace:, intake:)
      @workspace, @intake = workspace, intake
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      unless intake.is_a?(ProjectIntake) && intake.persisted? &&
             intake.workspace_id == workspace.id && intake.client_id.present? &&
             workspace.project_intakes.where(id: intake.id, client_id: intake.client_id).exists?
        raise Denied, "Invalid project context"
      end
      assert_synthetic_only!
    end

    def admit!(purpose:, data_class:, provider:, estimated_tokens:, estimated_usd:)
      @access.assert_owner!
      assert_synthetic_only!
      raise Denied, "Unregistered offline purpose" unless AiPolicy::PURPOSES.include?(purpose)
      raise Denied, "Only synthetic data can be admitted" unless data_class == "synthetic"
      raise Denied, "External AI provider is unavailable" unless provider == "offline_template"
      unless estimated_tokens.is_a?(Integer) && estimated_tokens.zero? &&
             estimated_usd.is_a?(Numeric) && estimated_usd == 0
        raise Denied, "Nonzero or untrusted cost estimate denied"
      end

      defaults = @workspace.studio_ai_policies.find_by(project_intake_id: nil)
      override = @workspace.studio_ai_policies.find_by(project_intake_id: @intake.id)
      unless defaults && AiPolicy::MODES.include?(defaults.mode) &&
             defaults.mode != "off" && defaults.purposes.include?(purpose)
        raise Denied, "Workspace policy does not allow offline assistance"
      end
      if override && (!AiPolicy::MODES.include?(override.mode) ||
           override.mode == "off" || !override.purposes.include?(purpose))
        raise Denied, "Project policy blocks offline assistance"
      end
      requested = if defaults.mode == "reviewed_provider" &&
                     (override.nil? || override.mode == "reviewed_provider")
                    "reviewed_provider_unavailable"
                  else
                    "offline"
                  end

      # No remaining budget and no external consent is inferred from a UI flag.
      {
        status: "offline_admitted",
        provider: "offline_template",
        requested_mode: requested,
        permitted_data_class: "synthetic",
        tokens_reserved: 0,
        usd_reserved: 0,
        external_call_permitted: false,
        billing_permitted: false
      }
    end

    private

    def assert_synthetic_only!
      unless !Rails.env.production? &&
             (Rails.env.test? ||
              (Rails.env.development? && ENV["RC_STUDIO_AI_OFFLINE"] == "true"))
        raise Denied, "Budget gate is nonproduction synthetic-only"
      end
    end
  end
end
