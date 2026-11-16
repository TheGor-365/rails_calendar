module OwnerAi
  # Human-reviewed apply of ONE bounded text field to ONE existing service draft.
  # Never edits approved/published versions, never changes scope/exclusions/price.
  class DraftApplier
    class Conflict < StandardError; end

    def initialize(workspace:)
      @workspace = workspace
      @catalogue = OwnerServices::Catalogue.new(workspace: workspace)
      @profile = @catalogue.profile
    end

    def apply!(entry:, offering_id:, base_version:, base_digest:, summary:, confirmed:)
      raise Conflict, "Owner confirmation required" unless confirmed
      snapshot = @catalogue.snapshot
      raise Conflict, "Owner context is not approved/current" unless
        snapshot && @profile.onboarding_state == "approved" &&
        @profile.professional_capability_corrections.none?
      raise Conflict, "AI result is not owned/current" unless
        entry&.status == "settled" && entry.professional_profile_id == @profile.id &&
        entry.operation == OwnerAi::Composer::VERSION &&
        entry.result.is_a?(Hash) && entry.result["purpose"] == "service_copy" &&
        entry.result["profile_version"].to_s == snapshot.version.to_s
      text = summary.to_s.strip
      raise Conflict, "Review the complete service summary" unless text.length.between?(25, 1000)
      raise Conflict, "Missing optimistic lock" unless base_digest.to_s.match?(/\A[0-9a-f]{64}\z/)

      offering = @workspace.service_offerings.find_by(id: offering_id)
      raise Conflict, "Service not found" unless offering
      draft = offering.draft_version
      raise Conflict, "No matching private draft revision" unless
        draft && draft.version.to_s == base_version.to_s &&
        draft.digest == base_digest && draft.professional_context_snapshot_id == snapshot.id

      # Retain ALL other fields exactly, especially restrictions/exclusions.
      @catalogue.update_draft!(
        offering: offering, version: base_version, digest: base_digest,
        attributes: {
          title: draft.title,
          summary: text,
          included_scope: draft.included_scope,
          excluded_scope: draft.excluded_scope,
          requirements_prompt: draft.requirements_prompt,
          project_category: draft.project_category
        }
      )
    rescue OwnerServices::Catalogue::Conflict,
           OwnerServices::Catalogue::PolicyError,
           ActiveRecord::RecordInvalid, ActiveRecord::ReadOnlyError
      raise Conflict, "Draft changed or input is invalid; reload and review"
    end
  end
end
