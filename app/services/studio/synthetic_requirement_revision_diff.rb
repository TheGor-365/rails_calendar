require "digest"
require "json"

module Studio
  # RC-038 Slice F. In-memory, fictional owner-reviewed requirement-set diff.
  # A source locator is only a matching hint, NEVER a permanent requirement ID.
  class SyntheticRequirementRevisionDiff
    VERSION = "rc038-synthetic-revision-diff.v1".freeze
    CATEGORIES = %w[
      unchanged_unverified changed_unverified newly_retained_unverified
      no_longer_retained_unverified
    ].freeze

    class Denied < StandardError; end

    def initialize(actor:, workspace:)
      @actor, @workspace = actor, workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      @trace = SyntheticRequirementTracePreview.new(actor: actor, workspace: workspace)
      @normalizer = SyntheticSourceNormalizer.new(actor: actor, workspace: workspace)
    end

    # previous/current are exact descriptors:
    # { baseline: {source_id:,filename:,bytes:},
    #   incoming: {source_id:,filename:,bytes:},
    #   expected_digest: "64 lowercase sha256 characters" }
    # All content is fictional and kept in memory only.
    def call(client:, intake:, previous:, current:, explicit_synthetic: false)
      @access.assert_owner!
      @access.assert_client!(client)
      unless !Rails.env.production? &&
             (Rails.env.test? || (Rails.env.development? &&
               ENV["RC_STUDIO_RC038_SYNTHETIC"] == "true")) &&
             explicit_synthetic == true
        raise Denied, "Synthetic revision comparison only"
      end

      prior = build_snapshot(client: client, intake: intake, descriptor: previous)
      latest = build_snapshot(client: client, intake: intake, descriptor: current)
      eligible = prior.fetch("trace").fetch("eligible_for_unapproved_synthetic_outline_review") &&
                 latest.fetch("trace").fetch("eligible_for_unapproved_synthetic_outline_review")
      # No actionable diff when either snapshot has unresolved, unknown,
      # untriaged or incomplete evidence. Never suggest deletions from gaps.
      deltas = eligible ? compare_traces(prior.fetch("items"), latest.fetch("items")) : []
      counts = CATEGORIES.index_with { |name|
        deltas.count { |entry| entry.fetch("classification") == name }
      }

      {
        "schema_version" => VERSION,
        "classification" => "UNTRUSTED_SYNTHETIC_REVISION_PREVIEW",
        "previous_comparison_digest" => previous.fetch(:expected_digest),
        "current_comparison_digest" => current.fetch(:expected_digest),
        "eligible_for_unapproved_synthetic_diff_review" => !!eligible,
        "blocked_reason" => eligible ? nil : "owner_triage_or_coverage_incomplete",
        "delta_count" => deltas.length, "delta_counts" => counts, "deltas" => deltas,
        "locator_identity_authoritative" => false,
        "automatic_supersession" => false, "automatic_deletion" => false,
        "requirement_approved" => false, "scope_approved" => false,
        "client_confirmed" => false, "document_generation_allowed" => false,
        "persisted" => false, "source_content_stored" => false,
        "external_calls" => 0, "billable_usd" => 0,
        "required_gates" => %w[owner_review client_confirmation privacy_release]
      }
    end

    private

    def build_snapshot(client:, intake:, descriptor:)
      unless descriptor.is_a?(Hash) &&
             descriptor.keys.sort == %i[baseline incoming expected_digest].sort &&
             descriptor[:expected_digest].is_a?(String) &&
             descriptor[:expected_digest].match?(/\A[0-9a-f]{64}\z/)
        raise Denied, "Exact source revision descriptor required"
      end

      trace = @trace.call(client: client, intake: intake,
        baseline: descriptor.fetch(:baseline), incoming: descriptor.fetch(:incoming),
        expected_digest: descriptor.fetch(:expected_digest), explicit_synthetic: true)

      incoming = descriptor.fetch(:incoming)
      # Normalizer rejects wrong tenant, stale hashes and quarantined sources.
      # This second ephemeral normalization permits content identity across
      # whole-file revisions without persisting or returning raw values/digests.
      unless incoming.is_a?(Hash) && incoming.keys.sort == %i[source_id filename bytes].sort
        raise Denied, "Exact incoming source descriptor required"
      end
      graph = @normalizer.call(client: client, intake: intake,
        source_id: incoming.fetch(:source_id), filename: incoming.fetch(:filename),
        bytes: incoming.fetch(:bytes), explicit_synthetic: true)
      facts = graph.fetch("fact_candidates").index_by { |item| item.fetch("id") }
      segments = graph.fetch("segments").index_by { |item| item.fetch("id") }

      items = trace.fetch("trace_candidates").map do |candidate|
        fact = facts.fetch(candidate.fetch("incoming_fact_id")) do
          raise Denied, "Stale candidate fact"
        end
        segment = segments.fetch(candidate.fetch("incoming_segment_id")) do
          raise Denied, "Stale source segment"
        end
        unless fact.fetch("source_segment_id") == segment.fetch("id") &&
               candidate.fetch("incoming_locator") == segment.fetch("locator")
          raise Denied, "Invalid provenance edge"
        end
        { "locator" => segment.fetch("locator"), "type" => fact.fetch("type"),
          "value_sha256" => segment.fetch("text_sha256"),
          "trace_id" => candidate.fetch("trace_id"),
          "receipt_id" => candidate.fetch("owner_triage_receipt_id") }
      end
      raise Denied, "Duplicate synthetic source locator" unless
        items.map { |row| [row.fetch("locator"), row.fetch("type")] }.uniq.size == items.size

      { "trace" => trace, "items" => items }
    end

    def compare_traces(before, after)
      old_index = before.index_by { |r| [r.fetch("locator"), r.fetch("type")] }
      new_index = after.index_by { |r| [r.fetch("locator"), r.fetch("type")] }
      keys = (old_index.keys | new_index.keys).sort

      keys.map do |key|
        previous = old_index[key]
        current = new_index[key]
        status =
          if previous && current
            previous.fetch("value_sha256") == current.fetch("value_sha256") ?
              "unchanged_unverified" : "changed_unverified"
          elsif current
            "newly_retained_unverified"
          else
            "no_longer_retained_unverified"
          end

        {
          # This identifier is only a deterministic preview coordinate. It
          # must not be used for authorizing access or approving requirements.
          "coordinate_id" => "coord-#{Digest::SHA256.hexdigest(
            JSON.generate([VERSION, @workspace.id, key])
          ).first(24)}",
          "classification" => status,
          "previous_trace_id" => previous&.fetch("trace_id"),
          "current_trace_id" => current&.fetch("trace_id"),
          "previous_triage_receipt_id" => previous&.fetch("receipt_id"),
          "current_triage_receipt_id" => current&.fetch("receipt_id"),
          "requires_owner_and_client_review" => true,
          "may_auto_approve" => false, "may_auto_supersede" => false
        }
      end
    end
  end
end
