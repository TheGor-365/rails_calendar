module Studio
  # An explicit operator action on already authenticated in-memory synthetic
  # comparison evidence. Does NOT create a ClientFact or grant approval.
  class SyntheticReviewTriage
    class Denied < StandardError; end
    class Conflict < StandardError; end
    CONFIRM_PREFIX = "REVIEW-SYNTHETIC-".freeze

    def initialize(actor:, workspace:)
      @actor, @workspace = actor, workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def call(client:, intake:, baseline:, incoming:, expected_digest:,
             incoming_fact_id:, resolution:, confirmation:, explicit_synthetic: false)
      @access.assert_owner!
      @access.assert_client!(client)

      unless !Rails.env.production? &&
             (Rails.env.test? || (Rails.env.development? &&
               ENV["RC_STUDIO_RC038_SYNTHETIC"] == "true")) && explicit_synthetic == true
        raise Denied, "Synthetic triage only"
      end
      unless expected_digest.is_a?(String) && expected_digest.match?(/\A[0-9a-f]{64}\z/) &&
             incoming_fact_id.is_a?(String) && incoming_fact_id.match?(/\Afact-[0-9a-f]{24}\z/) &&
             SyntheticReviewDecision::RESOLUTIONS.include?(resolution)
        raise Denied, "Unsupported review request"
      end
      unless confirmation == "#{CONFIRM_PREFIX}#{expected_digest.first(12)}"
        raise Denied, "Explicit review confirmation required"
      end

      # Rebuild both graphs from bytes, never trust a client-supplied state,
      # comparison response or source ID without the normalizer ACL.
      comparison = SyntheticSourceReconciliation.new(
        actor: @actor, workspace: @workspace
      ).call(client: client, intake: intake, baseline: baseline, incoming: incoming,
             explicit_synthetic: true)
      raise Conflict, "Comparison has changed" unless comparison.fetch("comparison_digest") == expected_digest

      candidate = comparison.fetch("comparisons").find { |row|
        row.fetch("incoming_fact_id") == incoming_fact_id
      }
      raise Denied, "Candidate not found" unless candidate
      state = candidate.fetch("state")
      if resolution == "retain_for_review" && !%w[new corroborates].include?(state)
        raise Denied, "Unresolved candidate needs clarification or exclusion"
      end

      # Row lock serializes duplicate/conflicting attempts. One immutable
      # decision per source-pair fingerprint and candidate ID; revised content
      # creates a new digest and a separate review event.
      @workspace.project_intakes.where(client_id: client.id).lock.find(intake.id).with_lock do
        scope = @workspace.studio_synthetic_review_decisions.where(
          project_intake_id: intake.id, comparison_digest: expected_digest,
          incoming_fact_id: incoming_fact_id
        )
        existing = scope.first
        if existing
          unless existing.resolution == resolution && existing.candidate_state == state &&
                 existing.baseline_source_id == comparison.fetch("baseline_source_id") &&
                 existing.incoming_source_id == comparison.fetch("incoming_source_id")
            raise Conflict, "Immutable triage decision already exists"
          end
          return receipt(existing)
        end

        row = scope.create!(
          client: client, baseline_source_id: comparison.fetch("baseline_source_id"),
          incoming_source_id: comparison.fetch("incoming_source_id"),
          reviewed_by: @actor, candidate_state: state,
          resolution: resolution, reviewed_at: Time.current
        )
        receipt(row)
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Scoped project not found"
    end

    private

    def receipt(row)
      { "receipt_id" => row.id, "candidate_state" => row.candidate_state,
        "resolution" => row.resolution, "record_type" => "synthetic_owner_triage_only",
        "source_content_stored" => false, "approved" => false,
        "client_confirmation" => false, "external_calls" => 0 }
    end
  end
end
