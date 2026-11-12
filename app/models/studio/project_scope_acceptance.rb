module Studio
  # Immutable test-only receipt for the EXACT approved spec revision and a
  # currently accessible client grant. No HTML endpoint or production access.
  class ProjectScopeAcceptance < ApplicationRecord
    self.table_name = "studio_project_scope_acceptances"

    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake
    belongs_to :intake_spec_version
    belongs_to :client_project_grant, class_name: "Studio::ClientProjectGrant",
               foreign_key: :studio_client_project_grant_id
    belongs_to :client_account, class_name: "Studio::ClientAccount",
               foreign_key: :studio_client_account_id
    has_one :project, class_name: "Studio::Project",
            foreign_key: :studio_project_scope_acceptance_id,
            dependent: :restrict_with_exception

    attr_accessor :accepting_actor

    validates :document_sha256, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :accepted_at, presence: true
    validate :exact_test_only_client_scope
    before_update :deny_mutation
    before_destroy :deny_mutation

    private

    def exact_test_only_client_scope
      valid = Rails.env.test? && !Rails.env.production? &&
        accepting_actor.is_a?(Studio::ClientAccount) &&
        accepting_actor.active? && accepting_actor.id == studio_client_account_id &&
        client_project_grant&.accessible_for?(accepting_actor) &&
        workspace&.state == "internal" &&
        client&.workspace_id == workspace_id &&
        project_intake&.workspace_id == workspace_id &&
        project_intake&.client_id == client_id &&
        intake_spec_version&.project_intake_id == project_intake_id &&
        intake_spec_version&.approved? &&
        client_project_grant&.workspace_id == workspace_id &&
        client_project_grant&.client_id == client_id &&
        client_project_grant&.project_intake_id == project_intake_id &&
        document_sha256 == Studio::ProjectScopeFingerprint.call(intake_spec_version.document)
      errors.add(:base, "Exact authenticated fictional scope required") unless valid
    end

    def deny_mutation
      errors.add(:base, "Accepted specification receipts are immutable")
      throw :abort
    end
  end
end
