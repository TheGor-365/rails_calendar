module OwnerAi
  # RC055.1f C2.0: A read-only, owner-scoped inventory of information the
  # assistant may actually use. This is deliberately NOT a retrieval adapter.
  # Private service drafts, attachments and customer records remain excluded.
  class KnowledgeReadiness
    def initialize(workspace:)
      @workspace = workspace
      @profile = workspace.professional_profile
      @snapshot = @profile&.approved_snapshot
    end

    def approved_profile?
      @snapshot.present? &&
        @profile.onboarding_state == "approved" &&
        @profile.professional_capability_corrections.none?
    end

    def approved_public_facts?
      return false unless approved_profile?
      payload = @snapshot.payload
      payload.is_a?(Hash) && payload["headline"].present? &&
        (payload["public_summary_draft"].presence || payload["public_summary"].presence).present?
    end

    def profile_version
      @snapshot&.version
    end

    # These counts are owner-private inventory metadata, not a promise of
    # public visibility or authorization to send services to the model.
    def private_service_count
      @workspace.service_offerings.count
    end

    def approved_service_count
      @workspace.service_offerings.where.not(approved_version_id: nil).count
    end

    def published_service_count
      @workspace.service_offerings.where.not(published_version_id: nil).count
    end

    # No structured owner-approved FAQ/price-policy store or consented
    # document extraction pipeline exists in this release branch. Do not
    # infer readiness from free-form interview notes or attached files.
    def faq_and_prices_available_to_client_ai?
      false
    end

    def documents_available_to_ai?
      false
    end

    def service_catalogue_available_to_composer?
      false
    end
  end
end
