require "digest"
require "json"

module Studio
  # RC-038 Slice G: fictional, read-only change-control packet for future
  # document revisions. Reuses verified owner-scoped synthetic revision diff.
  # Never creates an ArtifactRevision, approval, document, export or AI call.
  class SyntheticDocumentRevisionImpact
    VERSION = "rc038-synthetic-document-impact.v1".freeze
    PRIORITY = {
      "changed_unverified" => 0,
      "no_longer_retained_unverified" => 1,
      "newly_retained_unverified" => 2
    }.freeze
    class Denied < StandardError; end

    def initialize(actor:, workspace:)
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      @diff = SyntheticRequirementRevisionDiff.new(actor: actor, workspace: workspace)
      @planner = DocumentGenerationPlan.new
    end

    def call(client:, intake:, previous:, current:, explicit_synthetic: false)
      @access.assert_owner!
      @access.assert_client!(client)
      unless !Rails.env.production? &&
             (Rails.env.test? || (Rails.env.development? &&
               ENV["RC_STUDIO_RC038_SYNTHETIC"] == "true")) &&
             explicit_synthetic == true
        raise Denied, "Only fictional, explicitly opted-in revision planning"
      end

      diff = @diff.call(client: client, intake: intake, previous: previous,
                        current: current, explicit_synthetic: true)
      eligible = diff.fetch("eligible_for_unapproved_synthetic_diff_review")
      queue = eligible ? review_queue(diff.fetch("deltas")) : []
      # An empty evidence set is intentional. Synthetic triage is not client
      # confirmation, an approved scope, inspected real source or a reviewed
      # artifact. The document planner must not inherit fictional approvals.
      gates = @planner.call(evidence: {}).fetch("artifacts")
      unless gates.all? { |item| item.fetch("status") == "blocked" }
        raise Denied, "Synthetic input cannot unlock generation gates"
      end

      artifacts = queue.empty? ? [] : gates.map do |item|
        {
          "artifact_key" => item.fetch("key"),
          "impact_state" => "manual_assessment_candidate",
          "generation_state" => "blocked",
          "missing_evidence" => item.fetch("missing_evidence"),
          "requires_owner_and_client_review" => true
        }
      end

      report_id = "review-#{Digest::SHA256.hexdigest(JSON.generate([
        VERSION, @workspace.id, intake.id, diff.fetch("previous_comparison_digest"),
        diff.fetch("current_comparison_digest"),
        queue.map { |row| [row.fetch("coordinate_id"), row.fetch("classification")] }
      ])).first(24)}"

      {
        "schema_version" => VERSION,
        "classification" => "UNAPPROVED_FICTIONAL_CHANGE_CONTROL_PREVIEW",
        "review_report_id" => report_id,
        "review_report_id_is_authorization" => false,
        "previous_comparison_digest" => diff.fetch("previous_comparison_digest"),
        "current_comparison_digest" => diff.fetch("current_comparison_digest"),
        "source_review_complete" => eligible,
        "review_state" => if !eligible
                            "blocked_unresolved_source_review"
                          elsif queue.empty?
                            "no_change_observed_not_verified"
                          else
                            "manual_change_assessment_pending"
                          end,
        "change_count" => queue.length,
        "review_queue" => queue,
        "artifact_review_candidates" => artifacts,
        "document_generation_gates" => gates.map do |item|
          { "artifact_key" => item.fetch("key"), "state" => "blocked",
            "missing_evidence" => item.fetch("missing_evidence") }
        end,
        "locator_identity_authoritative" => false,
        "automatic_deletion" => false,
        "automatic_supersession" => false,
        "automatic_document_revision" => false,
        "requirement_approved" => false, "scope_approved" => false,
        "client_confirmed" => false, "document_generation_allowed" => false,
        "persisted" => false, "source_content_stored" => false,
        "external_calls" => 0, "billable_usd" => 0,
        "required_gates" => %w[owner_review client_confirmation privacy_release]
      }
    end

    private

    def review_queue(rows)
      rows.filter_map do |row|
        category = row.fetch("classification")
        next if category == "unchanged_unverified"
        raise Denied, "Unrecognized synthetic change category" unless PRIORITY.key?(category)

        {
          "coordinate_id" => row.fetch("coordinate_id"),
          "classification" => category,
          "previous_trace_id" => row.fetch("previous_trace_id"),
          "current_trace_id" => row.fetch("current_trace_id"),
          "owner_review_state" => "pending",
          "client_confirmation_state" => "not_requested",
          "deletion_authorized" => false,
          "supersession_authorized" => false
        }
      end.sort_by { |row| [PRIORITY.fetch(row.fetch("classification")),
                           row.fetch("coordinate_id")] }
    end
  end
end
