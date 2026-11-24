require "json"

module OwnerAi
  # Only public, immutable service fields from the current approved snapshot.
  # No drafts, hidden conditions, attachments, customer records or prices.
  class CatalogueContext
    MAX_SERVICES = 9
    MAX_BYTES = 3500

    def initialize(workspace:)
      @workspace = workspace
    end

    def entries
      profile = @workspace.professional_profile
      snapshot = profile&.approved_snapshot
      return [] unless snapshot && profile.onboarding_state == "approved" &&
        profile.professional_capability_corrections.none?

      rows = []
      @workspace.service_offerings.where.not(published_version_id: nil)
        .includes(:published_version).order(:position, :id).limit(MAX_SERVICES).each do |offering|
        version = offering.published_version
        next unless version&.approved? && version.service_offering_id == offering.id &&
          version.professional_context_snapshot_id == snapshot.id
        row = {
          "title" => version.title,
          "summary" => version.summary,
          "included_scope" => version.included_scope,
          "delivery_mode" => version.delivery_mode,
          "version" => version.version
        }
        break if JSON.generate(rows + [row]).bytesize > MAX_BYTES
        rows << row
      end
      rows
    end
  end
end
