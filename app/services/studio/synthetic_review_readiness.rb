module Studio
  # RC-038 Slice D: read-only, synthetic-only readiness for a possible
  # UNAPPROVED outline review. Never emits or stores a document or source text.
  class SyntheticReviewReadiness
    class Denied < StandardError; end
    class Conflict < StandardError; end

    VERSION = "rc038-review-readiness.v1".freeze

    def initialize(actor:, workspace:)
      @actor, @workspace = actor, workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def call(client:, intake:, baseline:, incoming:, expected_digest:,
             explicit_synthetic: false)
      @access.assert_owner!
      @access.assert_client!(client)
      unless !Rails.env.production? &&
             (Rails.env.test? || (Rails.env.development? &&
               ENV["RC_STUDIO_RC038_SYNTHETIC"] == "true")) &&
             explicit_synthetic == true
        raise Denied, "Synthetic readiness only"
      end
      unless expected_digest.is_a?(String) &&
             expected_digest.match?(/\A[0-9a-f]{64}\z/)
        raise Denied, "Exact synthetic comparison digest required"
      end

      comparison = SyntheticSourceReconciliation.new(
        actor: @actor, workspace: @workspace
      ).call(client: client, intake: intake, baseline: baseline, incoming: incoming,
             explicit_synthetic: true)
      unless comparison.fetch("comparison_digest") == expected_digest
        raise Conflict, "Comparison has changed"
      end

      # Only metadata from the exact workspace/client/intake/digest is read.
      # No source text, uploaded bytes, historical client facts or AI output.
      receipts = @workspace.studio_synthetic_review_decisions.where(
        client_id: client.id, project_intake_id: intake.id,
        comparison_digest: expected_digest
      ).to_a.index_by(&:incoming_fact_id)
      candidates = comparison.fetch("comparisons")
      expected_ids = candidates.map { |item| item.fetch("incoming_fact_id") }
      raise Denied, "Unexpected synthetic receipt" unless (receipts.keys - expected_ids).empty?

      items = candidates.map do |candidate|
        id = candidate.fetch("incoming_fact_id")
        receipt = receipts[id]
        if receipt && (receipt.reviewed_by_id != @actor.id ||
                       receipt.baseline_source_id != comparison.fetch("baseline_source_id") ||
                       receipt.incoming_source_id != comparison.fetch("incoming_source_id") ||
                       receipt.candidate_state != candidate.fetch("state"))
          raise Denied, "Stale or inconsistent synthetic receipt"
        end

        resolution = receipt&.resolution || "not_reviewed"
        { "incoming_fact_id" => id, "state" => candidate.fetch("state"),
          "resolution" => resolution, "receipt_id" => receipt&.id,
          "requires_human_review" => true }
      end

      counts = %w[not_reviewed needs_information retain_for_review exclude_from_draft]
               .index_with { |state| items.count { |item| item.fetch("resolution") == state } }
      fully_triaged = items.any? && counts["not_reviewed"].zero? &&
                      counts["needs_information"].zero?
      no_ambiguity = comparison.fetch("coverage") == "complete" &&
                     items.all? { |item| %w[new corroborates].include?(item.fetch("state")) }
      may_plan = fully_triaged && no_ambiguity && counts["retain_for_review"].positive?

      {
        "schema_version" => VERSION,
        "classification" => "UNTRUSTED_SYNTHETIC_REVIEW_METADATA",
        "comparison_digest" => expected_digest, "coverage" => comparison.fetch("coverage"),
        "candidate_count" => items.size, "resolution_counts" => counts,
        "candidates" => items,
        "eligible_for_unapproved_synthetic_outline_review" => may_plan,
        "document_generation_allowed" => false, "source_content_stored" => false,
        "client_confirmed" => false, "scope_approved" => false,
        "external_calls" => 0, "billable_usd" => 0,
        "required_gates" => %w[owner_review client_confirmation privacy_release]
      }
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Scoped project not found"
    end
  end
end
