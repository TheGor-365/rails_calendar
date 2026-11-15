require "digest"
require "json"

module OwnerServices
  # One explicit owner action to finalize precisely the visible, unchanged
  # draft set. Approval is atomic and never enables public/client visibility.
  class BulkApproval
    class Conflict < StandardError; end

    def initialize(workspace:)
      @workspace = workspace
      @catalogue = Catalogue.new(workspace: workspace)
    end

    def drafts
      @workspace.service_offerings.order(:id).filter_map do |offering|
        draft = offering.draft_version
        [offering, draft] if draft
      end
    end

    def fingerprint
      snapshot = @catalogue.snapshot
      Digest::SHA256.hexdigest(JSON.generate([
        snapshot&.id,
        drafts.map { |offering, draft| [offering.id, draft.id, draft.digest] }
      ]))
    end

    def approve_all!(expected_fingerprint:)
      count = 0
      ServiceOffering.transaction do
        @workspace.lock!
        raise Conflict, "The visible draft set changed; refresh first" unless
          expected_fingerprint.present? && fingerprint == expected_fingerprint

        entries = drafts
        raise Conflict, "No drafts" if entries.empty?

        entries.each do |offering, draft|
          @catalogue.approve!(
            offering: offering, version: draft.version,
            digest: draft.digest, confirmed: true
          )
          count += 1
        end
      end
      count
    end
  end
end
