require "digest"
require "json"
require "set"

module Studio
  # RC-038 Slice B: ephemeral, conservative comparison of TWO already
  # owner-scoped synthetic source graphs. Never writes facts or approvals.
  class SyntheticSourceReconciliation
    VERSION = "rc038-reconciliation.v1".freeze
    STATES = %w[new corroborates conflicts unknown].freeze

    def initialize(actor:, workspace:)
      @normalizer = SyntheticSourceNormalizer.new(actor: actor, workspace: workspace)
    end

    # Each source descriptor contains :source_id, :filename, :bytes.
    # The normalizer rechecks actor, workspace/client/intake, source fingerprint,
    # quarantined state, production gate and explicit synthetic opt-in.
    def call(client:, intake:, baseline:, incoming:, explicit_synthetic: false)
      older = normalize(client: client, intake: intake, source: baseline,
                        explicit_synthetic: explicit_synthetic)
      newer = normalize(client: client, intake: intake, source: incoming,
                        explicit_synthetic: explicit_synthetic)

      old_segments = older.fetch("segments").index_by { |s| s.fetch("id") }
      new_segments = newer.fetch("segments").index_by { |s| s.fetch("id") }
      old_facts = older.fetch("fact_candidates")
      new_facts = newer.fetch("fact_candidates")
      consumed = Set.new

      matches_by_value = old_facts.group_by do |fact|
        key(fact.fetch("type"), fact.fetch("value"))
      end
      matches_by_locator = old_facts.group_by do |fact|
        old_segments.fetch(fact.fetch("source_segment_id")).fetch("locator")
      end

      complete = older.fetch("coverage") == "complete" && newer.fetch("coverage") == "complete"
      comparisons = new_facts.map do |fact|
        segment = new_segments.fetch(fact.fetch("source_segment_id"))
        same_value = Array(matches_by_value[key(fact.fetch("type"), fact.fetch("value"))])
                     .reject { |candidate| consumed.include?(candidate.fetch("id")) }
        identical = same_value.find { |candidate|
          candidate.fetch("status") != "unknown" &&
            old_segments.fetch(candidate.fetch("source_segment_id")).fetch("locator") ==
              segment.fetch("locator")
        }
        relocated = same_value.any? { |candidate|
          old_segments.fetch(candidate.fetch("source_segment_id")).fetch("locator") !=
            segment.fetch("locator")
        }
        at_locator = Array(matches_by_locator[segment.fetch("locator")])
                     .find { |candidate| !consumed.include?(candidate.fetch("id")) }

        state, reason, reference =
          if fact.fetch("status") == "unknown"
            ["unknown", "incoming_value_unknown", at_locator]
          elsif identical
            ["corroborates", "exact_claim_match_not_verification", identical]
          elsif !complete
            ["unknown", "partial_evidence_no_absence_claim", at_locator]
          elsif relocated
            ["unknown", "same_text_different_locator", at_locator]
          elsif at_locator && at_locator.fetch("status") == "unknown"
            ["unknown", "previous_value_unknown", at_locator]
          elsif at_locator && at_locator.fetch("type") == fact.fetch("type")
            ["conflicts", "same_locator_different_claim", at_locator]
          elsif at_locator
            ["unknown", "different_claim_type", at_locator]
          else
            ["new", "not_observed_in_complete_baseline", nil]
          end

        consumed << reference.fetch("id") if reference
        {
          "incoming_fact_id" => fact.fetch("id"),
          "incoming_segment_id" => fact.fetch("source_segment_id"),
          "incoming_locator" => segment.fetch("locator"),
          "baseline_fact_id" => reference&.fetch("id"),
          "state" => state,
          "reason_code" => reason,
          "requires_human_review" => true,
          "may_auto_approve" => false,
          "may_auto_supersede" => false
        }
      end

      {
        "schema_version" => VERSION,
        "classification" => "UNTRUSTED_SYNTHETIC_EPHEMERAL",
        "comparison_digest" => Digest::SHA256.hexdigest(
          JSON.generate([VERSION, older.fetch("source_id"), newer.fetch("source_id"),
                         older.fetch("source_sha256"), newer.fetch("source_sha256")])
        ),
        "baseline_source_id" => older.fetch("source_id"),
        "incoming_source_id" => newer.fetch("source_id"),
        "baseline_coverage" => older.fetch("coverage"),
        "incoming_coverage" => newer.fetch("coverage"),
        "coverage" => complete ? "complete" : "partial",
        "comparisons" => comparisons,
        "counts" => STATES.index_with { |state| comparisons.count { |c| c.fetch("state") == state } },
        "baseline_not_observed_count" => old_facts.size - consumed.size,
        "automatic_supersedes" => 0,
        "persisted" => false, "approved" => false, "external_calls" => 0,
        "billable_usd" => 0, "human_decision_required" => true,
        "required_gates" => %w[human_review client_confirmation privacy_release]
      }
    end

    private

    def normalize(client:, intake:, source:, explicit_synthetic:)
      unless source.is_a?(Hash) && source.keys.sort == %i[bytes filename source_id].sort
        raise ArgumentError, "Expected an exact synthetic source descriptor"
      end

      @normalizer.call(client: client, intake: intake, source_id: source.fetch(:source_id),
                       filename: source.fetch(:filename), bytes: source.fetch(:bytes),
                       explicit_synthetic: explicit_synthetic)
    end

    def key(type, text)
      # Pure whitespace normalization is not evidence verification. Preserve
      # case, punctuation and meaning; do not fuzzy-match conflicting claims.
      [type, text.to_s.strip.gsub(/\s+/, " ")]
    end
  end
end
