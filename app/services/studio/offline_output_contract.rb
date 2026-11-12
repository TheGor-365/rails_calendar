module Studio
  # Exact output contract, fail-closed for client/billable/approved responses.
  # This validates a deterministic Ruby Hash, not an LLM response.
  class OfflineOutputContract
    class Denied < StandardError; end
    KEYS = %i[
      schema_version template_version status purpose mode_executed
      provider_requested provider_executed input_classification
      source_metadata_count text external_calls tokens_billed
      billable_usd auto_approved
    ].freeze

    def self.validate!(payload)
      unless payload.is_a?(Hash) && payload.keys.sort == KEYS.sort &&
             payload[:schema_version] == OfflineAiDispatcher::VERSION &&
             payload[:template_version] == OfflineTemplateRegistry::VERSION &&
             payload[:status] == "needs_human_review" &&
             Studio::AiPolicy::PURPOSES.include?(payload[:purpose]) &&
             payload[:mode_executed] == "offline" &&
             %w[offline reviewed_provider_unavailable].include?(payload[:provider_requested]) &&
             payload[:provider_executed] == "offline_template" &&
             payload[:input_classification] == "UNVERIFIED_SYNTHETIC_ONLY" &&
             payload[:source_metadata_count].is_a?(Integer) && payload[:source_metadata_count] >= 0 &&
             payload[:text].is_a?(String) && payload[:text].bytesize.between?(1, 512) &&
             payload[:text] == OfflineTemplateRegistry.render!(purpose: payload[:purpose]) &&
             payload[:external_calls] == 0 &&
             payload[:tokens_billed] == 0 &&
             payload[:billable_usd] == 0 &&
             payload[:auto_approved] == false
        raise Denied, "Offline-only output contract violated"
      end
      payload
    rescue ArgumentError
      raise Denied, "Unsupported offline output purpose"
    end
  end
end
