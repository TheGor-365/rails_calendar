module Studio
  module AiProviders
    # Stage-zero xAI contract rehearsal. Never opens HTTP or reads API credentials.
    # Run only in Rails TEST with fictional, owner-scoped project fixtures.
    # A real provider requires a separate persistent cost ledger and approval.
    class XaiGrokMockContract
      class Denied < StandardError; end
      class InvalidResponse < StandardError; end

      MODEL = "grok-4.7"
      MAX_INPUT_TOKENS = 1_200
      MAX_OUTPUT_TOKENS = 400
      MAX_MOCK_COST_TICKS = 100_000_000 # $0.01 in simulated xAI usage only.
      FIELDS = %w[source_ids suggestions unknowns why_ask confidence status].freeze

      def initialize(actor:, workspace:, intake:, response_adapter:)
        raise Denied, "Test-only synthetic mock" unless Rails.env.test? && !Rails.env.production?
        @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
        @access.assert_owner!
        unless intake.is_a?(ProjectIntake) && intake.persisted? &&
               intake.workspace_id == workspace.id && intake.client_id.present? &&
               workspace.project_intakes.where(id: intake.id, client_id: intake.client_id).exists?
          raise Denied, "Invalid project scope"
        end

        @response_adapter = response_adapter
      end

      def call(purpose:, data_class: "synthetic", source_ids: [])
        raise Denied, "Test-only synthetic mock" unless Rails.env.test? && !Rails.env.production?
        @access.assert_owner!
        raise Denied, "Unsupported purpose" unless Studio::AiPolicy::PURPOSES.include?(purpose)
        raise Denied, "Only fictional sources permitted" unless data_class == "synthetic"
        unless source_ids.is_a?(Array) && source_ids.size <= 8 &&
               source_ids.all? { |id| id.is_a?(Integer) && id.positive? } &&
               source_ids.uniq == source_ids
          raise Denied, "Untrusted source identifiers"
        end

        # No raw project titles, messages, files or free-form instructions enter
        # the adapter. This is a mocked shape-check, not live Grok execution.
        mock_request = {
          model: MODEL, purpose: purpose,
          source_ids: source_ids.dup.freeze,
          source_classification: "synthetic",
          max_output_tokens: MAX_OUTPUT_TOKENS, tools: []
        }.freeze
        parsed = JSON.parse(@response_adapter.call(mock_request))
        raise InvalidResponse unless parsed.is_a?(Hash) && parsed["model"] == MODEL

        usage = parsed.fetch("usage")
        raise InvalidResponse unless usage.is_a?(Hash)
        input_tokens = usage.fetch("input_tokens")
        output_tokens = usage.fetch("output_tokens")
        ticks = usage.fetch("cost_in_usd_ticks")
        unless input_tokens.is_a?(Integer) && input_tokens.between?(0, MAX_INPUT_TOKENS) &&
               output_tokens.is_a?(Integer) && output_tokens.between?(0, MAX_OUTPUT_TOKENS) &&
               ticks.is_a?(Integer) && ticks.between?(0, MAX_MOCK_COST_TICKS)
          raise InvalidResponse
        end

        messages = parsed.fetch("output")
        raise InvalidResponse unless messages.is_a?(Array)
        item = messages.find { |entry| entry.is_a?(Hash) && entry["type"] == "message" }
        content = item.fetch("content").find { |c| c["type"] == "output_text" }
        proposal = JSON.parse(content.fetch("text"))
        validate_proposal!(proposal, source_ids)

        # Ledger fields here are SIMULATED ONLY. No charge, budget reservation,
        # persistent billing record, user acceptance or provider egress occurs.
        {
          schema_version: "xai-grok-mock-v1", model: MODEL,
          provider_executed: "mock_only", status: "needs_human_review",
          purpose: purpose, source_metadata_count: source_ids.size,
          suggestions: proposal.fetch("suggestions"),
          unknowns: proposal.fetch("unknowns"),
          why_ask: proposal.fetch("why_ask"),
          confidence: proposal.fetch("confidence"),
          reported_mock_cost_ticks: ticks, input_tokens: input_tokens,
          output_tokens: output_tokens, billed_usd_ticks: 0,
          external_calls: 0, auto_approved: false
        }
      rescue JSON::ParserError, KeyError, TypeError, NoMethodError
        raise InvalidResponse, "Invalid synthetic provider output"
      end

      private

      def validate_proposal!(value, source_ids)
        raise InvalidResponse unless value.is_a?(Hash) && value.keys.sort == FIELDS.sort
        raise InvalidResponse unless value["status"] == "needs_human_review"
        raise InvalidResponse unless value["source_ids"] == source_ids
        raise InvalidResponse unless valid_strings?(value["suggestions"], max: 5, length: 300)
        raise InvalidResponse unless valid_strings?(value["unknowns"], max: 5, length: 250)
        raise InvalidResponse unless value["why_ask"].is_a?(String) &&
                                     value["why_ask"].length.between?(1, 300)
        raise InvalidResponse unless value["confidence"].is_a?(Numeric) &&
                                     value["confidence"].finite? &&
                                     value["confidence"].between?(0, 1)
      end

      def valid_strings?(value, max:, length:)
        value.is_a?(Array) && value.size <= max &&
          value.all? { |s| s.is_a?(String) && s.length.between?(1, length) }
      end
    end
  end
end
