require "securerandom"

module OwnerServices
  # Private owner-approved service catalog. No public route, AI call, price,
  # quote, or automatic client intake selection is created in RC055.1.
  class Catalogue
    class Conflict < StandardError; end
    class PolicyError < StandardError; end

    attr_reader :workspace, :profile

    def initialize(workspace:)
      @workspace = workspace
      @profile = workspace.professional_profile
    end

    def snapshot
      profile&.approved_snapshot
    end

    def eligible_capabilities
      return ProfessionalCapability.none unless snapshot
      profile.professional_capabilities.where(snapshot_version: snapshot.version)
        .where.not(delivery_mode: "excluded")
        .where.not(willingness: "not_interested")
        .order(:domain)
    end

    def self.delivery_mode_for(capability)
      return nil if capability.nil? || capability.willingness == "not_interested"
      case capability.delivery_mode
      when "direct"
        capability.experience_claim == "practiced" && capability.willingness == "actively_offer" ? "direct" : "conditional"
      when "ai_assisted"
        "conditional"
      when "evaluate_first"
        "evaluate_first"
      end
    end

    def create_draft!(attributes, stable_key: nil)
      ensure_approved_profile!
      if stable_key && !stable_key.match?(/\Aauto-[a-z0-9-]{1,27}\z/)
        raise PolicyError, "Invalid generated service key"
      end
      capability = eligible_capabilities.find_by(id: attributes.fetch(:professional_capability_id))
      raise PolicyError, "Choose a capability from the latest approved context" unless capability

      ServiceOffering.transaction do
        offering = workspace.service_offerings.create!(key: stable_key || "svc-#{SecureRandom.hex(10)}")
        offering.versions.create!(
          offered_fields(attributes).merge(
            version: 1, professional_context_snapshot: snapshot,
            professional_capability: capability,
            source_capability_domain: capability.domain,
            delivery_mode: self.class.delivery_mode_for(capability)
          )
        )
        offering
      end
    end

    def update_draft!(offering:, attributes:, version:, digest:)
      offering.with_lock do
        draft = offering.draft_version
        require_matching_draft!(draft, version, digest)
        draft.update!(offered_fields(attributes))
        draft
      end
    end

    def approve!(offering:, version:, digest:, confirmed:)
      raise PolicyError, "Owner must confirm the exact service boundaries" unless confirmed
      offering.with_lock do
        ensure_approved_profile!
        draft = offering.draft_version
        require_matching_draft!(draft, version, digest)
        raise Conflict, "Source context changed; create a new reviewed draft" unless
          draft.professional_context_snapshot_id == snapshot.id &&
          eligible_capabilities.exists?(id: draft.professional_capability_id)

        draft.update!(approved_at: Time.current)
        offering.update!(approved_version: draft)
        draft
      end
    end

    def publish!(offering:, version_id:, digest:, confirmed:, owner:)
      raise PolicyError, "Owner confirmation is required" unless confirmed
      offering.with_lock do
        ensure_approved_profile!
        approved = offering.approved_version
        raise Conflict, "Offering approval changed" unless
          approved&.id.to_s == version_id.to_s && approved&.digest == digest &&
          approved.approved? && approved.professional_context_snapshot_id == snapshot.id &&
          eligible_capabilities.exists?(id: approved.professional_capability_id)

        raise Conflict, "Already enabled" if offering.published_version_id == approved.id
        offering.update!(published_version: approved)
        offering.publications.create!(
          event: "publish", service_offering_version: approved, owner_user: owner
        )
        approved
      end
    end

    def unpublish!(offering:, owner:, confirmed:)
      raise PolicyError, "Owner confirmation is required" unless confirmed
      offering.with_lock do
        raise Conflict, "Service is not enabled" unless offering.published_version
        offering.update!(published_version: nil)
        offering.publications.create!(event: "unpublish", owner_user: owner)
      end
    end

    def new_revision!(offering:)
      offering.with_lock do
        ensure_approved_profile!
        raise Conflict, "Finish the existing draft first" if offering.draft_version
        original = offering.approved_version
        raise Conflict, "No approved version to revise" unless original
        capability = eligible_capabilities.find_by(domain: original.source_capability_domain)
        raise PolicyError, "Capability was removed or excluded in the current context" unless capability
        offering.versions.create!(
          offered_fields(original.attributes.symbolize_keys).merge(
            version: offering.versions.maximum(:version).to_i + 1,
            professional_context_snapshot: snapshot, professional_capability: capability,
            source_capability_domain: capability.domain,
            delivery_mode: self.class.delivery_mode_for(capability)
          )
        )
      end
    end

    private

    def offered_fields(attributes)
      %i[title summary included_scope excluded_scope requirements_prompt project_category].to_h do |key|
        [key, attributes[key].to_s.strip]
      end
    end

    def require_matching_draft!(draft, version, digest)
      raise Conflict, "Draft changed or was already approved" unless
        draft && draft.version.to_s == version.to_s && draft.digest == digest
    end

    def ensure_approved_profile!
      raise PolicyError, "Approve your professional context before editing services" unless
        snapshot && profile.onboarding_state == "approved" &&
        profile.professional_capability_corrections.none?
    end
  end
end
