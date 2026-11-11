module Studio
  # Deliberately no external providers: no SDK, API key, price or network call.
  class AiModelRegistry
    VERSION = "rc037-model-registry.v1".freeze
    OFFLINE_PLAN = {
      key: "offline_document_plan_v1", provider: "none", external: false,
      billable: false, purposes: %w[document_plan].freeze,
      data_classes: %w[synthetic].freeze, prompt_version: "none",
      output_schema: "document-plan.v1"
    }.freeze

    def self.list
      [OFFLINE_PLAN]
    end

    def self.lookup(purpose:, data_class:)
      OFFLINE_PLAN if OFFLINE_PLAN.fetch(:purposes).include?(purpose) &&
        OFFLINE_PLAN.fetch(:data_classes).include?(data_class)
    end
  end
end
