module Studio
  # Separate from ProjectIntake and ProjectMilestone. No live tasks are granted
  # by this internal-scope-locked record; future releases need a new admission.
  class Project < ApplicationRecord
    self.table_name = "studio_projects"

    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake
    belongs_to :intake_spec_version
    belongs_to :project_scope_acceptance, class_name: "Studio::ProjectScopeAcceptance",
               foreign_key: :studio_project_scope_acceptance_id
    belongs_to :created_by, class_name: "User"

    validates :status, inclusion: { in: ["internal_scope_locked"] }
    validates :document_sha256, format: { with: /\A[0-9a-f]{64}\z/ }
    validate :exact_test_only_accepted_scope
    before_update :deny_mutation
    before_destroy :deny_mutation

    private

    def exact_test_only_accepted_scope
      receipt = project_scope_acceptance
      valid = Rails.env.test? && !Rails.env.production? &&
        workspace&.owner_access?(created_by) &&
        client&.workspace_id == workspace_id &&
        project_intake&.workspace_id == workspace_id &&
        project_intake&.client_id == client_id &&
        intake_spec_version&.project_intake_id == project_intake_id &&
        intake_spec_version&.approved? &&
        receipt&.workspace_id == workspace_id &&
        receipt&.client_id == client_id &&
        receipt&.project_intake_id == project_intake_id &&
        receipt&.intake_spec_version_id == intake_spec_version_id &&
        receipt&.document_sha256 == document_sha256 &&
        document_sha256 == (intake_spec_version && Studio::ProjectScopeFingerprint.call(intake_spec_version.document))
      errors.add(:base, "Internal accepted project requires exact owner and spec scope") unless valid
    end

    def deny_mutation
      errors.add(:base, "Internal project identity is immutable in this slice")
      throw :abort
    end
  end
end
