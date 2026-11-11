require "digest"

module Studio
  # RC-038 Slice E: metadata-only provenance for owner-retained, entirely
  # fictional requirement candidates. This never materializes an approved
  # Requirement, ClientFact, document or client-visible output.
  class SyntheticRequirementTracePreview
    VERSION = "rc038-requirement-trace.v1".freeze
    class Denied < StandardError; end

    def initialize(actor:, workspace:)
      @workspace = workspace
      @readiness = SyntheticReviewReadiness.new(actor: actor, workspace: workspace)
      @comparison = SyntheticSourceReconciliation.new(actor: actor, workspace: workspace)
    end

    def call(client:, intake:, baseline:, incoming:, expected_digest:,
             explicit_synthetic: false)
      # Readiness rechecks owner/tenant, input source fingerprints and every
      # existing immutable triage receipt. It always denies production.
      readiness = @readiness.call(
        client: client, intake: intake, baseline: baseline, incoming: incoming,
        expected_digest: expected_digest, explicit_synthetic: explicit_synthetic
      )
      comparison = @comparison.call(
        client: client, intake: intake, baseline: baseline, incoming: incoming,
        explicit_synthetic: explicit_synthetic
      )
      raise Denied, "Synthetic comparison changed" unless
        readiness.fetch("comparison_digest") == comparison.fetch("comparison_digest")

      reviewed = readiness.fetch("candidates").index_by do |row|
        row.fetch("incoming_fact_id")
      end
      comparisons = comparison.fetch("comparisons")
      raise Denied, "Synthetic review graph mismatch" unless
        reviewed.size == comparisons.size &&
        reviewed.keys.sort == comparisons.map { |row| row.fetch("incoming_fact_id") }.sort

      traces = comparisons.filter_map do |candidate|
        decision = reviewed.fetch(candidate.fetch("incoming_fact_id"))
        next unless decision.fetch("resolution") == "retain_for_review"

        # A retain-for-review is NEVER client confirmation or verified scope.
        unless %w[new corroborates].include?(candidate.fetch("state")) &&
               decision.fetch("state") == candidate.fetch("state") &&
               decision.fetch("receipt_id").present?
          raise Denied, "Invalid retained synthetic claim"
        end

        {
          "trace_id" => "trace-#{Digest::SHA256.hexdigest(
            [VERSION, @workspace.id, intake.id, expected_digest,
             candidate.fetch("incoming_fact_id")].join(":")
          ).first(24)}",
          "incoming_fact_id" => candidate.fetch("incoming_fact_id"),
          "incoming_source_id" => comparison.fetch("incoming_source_id"),
          "incoming_segment_id" => candidate.fetch("incoming_segment_id"),
          "incoming_locator" => candidate.fetch("incoming_locator"),
          "baseline_source_id" => comparison.fetch("baseline_source_id"),
          "baseline_fact_id" => candidate.fetch("baseline_fact_id"),
          "owner_triage_receipt_id" => decision.fetch("receipt_id"),
          "candidate_state" => candidate.fetch("state"),
          "trust" => "unverified_synthetic_source_report",
          "requirement_status" => "unapproved_candidate"
        }
      end

      {
        "schema_version" => VERSION,
        "classification" => "UNTRUSTED_SYNTHETIC_TRACE_ONLY",
        "comparison_digest" => expected_digest,
        "coverage" => comparison.fetch("coverage"),
        "candidate_count" => comparisons.size,
        "retained_trace_count" => traces.length,
        "resolution_counts" => readiness.fetch("resolution_counts"),
        "trace_candidates" => traces,
        "eligible_for_unapproved_synthetic_outline_review" =>
          readiness.fetch("eligible_for_unapproved_synthetic_outline_review"),
        "requirement_approved" => false, "client_confirmed" => false,
        "document_generation_allowed" => false, "source_content_stored" => false,
        "persisted" => false, "external_calls" => 0, "billable_usd" => 0,
        "required_gates" => %w[owner_review client_confirmation privacy_release]
      }
    end
  end
end
