module Studio
  # Deterministic prerequisites for a future Document Factory; this service
  # NEVER generates docs, spends tokens, accesses another tenant or calls AI.
  class DocumentGenerationPlan
    VERSION = "document-plan.v1".freeze
    DEFINITIONS = [
      { key: "discovery_brief", needs: %w[source_inspected], method: "offline_template" },
      { key: "clarification_questions", needs: %w[source_inspected], method: "offline_catalog" },
      { key: "requirements_spec", needs: %w[brief_reviewed client_confirmed], method: "reviewed_draft" },
      { key: "architecture", needs: %w[requirements_reviewed stack_confirmed], method: "reviewed_draft" },
      { key: "qa_plan", needs: %w[requirements_reviewed], method: "reviewed_draft" },
      { key: "full_roadmap", needs: %w[requirements_reviewed priorities_confirmed], method: "reviewed_draft" },
      { key: "financial_scenarios", needs: %w[roadmap_reviewed rates_confirmed costs_confirmed], method: "data_only" },
      { key: "pitch_deck", needs: %w[brief_reviewed roadmap_reviewed], method: "reviewed_draft" },
      { key: "handoff_bundle", needs: %w[scope_approved artifacts_approved], method: "deterministic_export" }
    ].freeze

    def call(evidence:)
      raise ArgumentError, "Evidence must be a string-keyed Hash" unless evidence.is_a?(Hash) &&
        evidence.keys.all? { |key| key.is_a?(String) }

      known = DEFINITIONS.flat_map { |item| item.fetch(:needs) }.uniq
      raise ArgumentError, "Unknown evidence keys" if (evidence.keys - known).any?
      raise ArgumentError, "Evidence values must be booleans" unless evidence.values.all? { |v| v == true || v == false }

      {
        "schema_version" => VERSION,
        "classification" => "OWNER_INTERNAL_ONLY_NO_GENERATION",
        "ai_calls" => 0,
        "artifacts" => DEFINITIONS.map do |item|
          missing = item.fetch(:needs).reject { |name| evidence.fetch(name, false) }
          {
            "key" => item.fetch(:key),
            "status" => missing.empty? ? "ready_to_propose" : "blocked",
            "missing_evidence" => missing,
            "depends_on" => item.fetch(:needs),
            "method" => item.fetch(:method),
            "requires_human_review" => true
          }
        end
      }
    end
  end
end
