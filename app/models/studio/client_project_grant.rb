module Studio
  # A one-to-one acceptance receipt, NOT a general workspace membership.
  # The permission surface is limited to a minimal project summary in dev/test.
  class ClientProjectGrant < ApplicationRecord
    self.table_name = "studio_client_project_grants"
    belongs_to :client_account, class_name: "Studio::ClientAccount",
               foreign_key: :studio_client_account_id
    belongs_to :project_invitation
    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake

    CONSENT_POLICY = "studio_review_v1"
    validates :role, inclusion: { in: %w[reviewer] }
    validates :status, inclusion: { in: %w[active revoked] }
    validates :consent_policy, inclusion: { in: [CONSENT_POLICY] }
    validates :project_invitation_id, uniqueness: true
    validate :tenant_matches_invitation
    before_update :only_revoke
    before_destroy :prevent_destroy

    def accessible_for?(account)
      self.class.accessible.where(id: id, studio_client_account_id: account&.id).exists?
    end

    # Every request queries the DB again: grant, owner membership, invitation revoke,
    # workspace suspension and account suspension take effect immediately.
    scope :accessible, -> {
      joins(:client_account, project_invitation: :workspace)
        .where(studio_client_project_grants: { status: "active" })
        .where(studio_client_accounts: { status: "active" })
        .where(project_invitations: { status: "pending" })
        .where("project_invitations.expires_at > studio_client_project_grants.accepted_at")
        .where(workspaces: { state: "internal" })
        .where(<<~SQL.squish)
          EXISTS (
            SELECT 1 FROM workspace_memberships wm
            WHERE wm.workspace_id = studio_client_project_grants.workspace_id
              AND wm.user_id = workspaces.owner_user_id
              AND wm.role = 'owner'
              AND wm.status = 'active'
          )
        SQL
    }

    private

    def tenant_matches_invitation
      return unless project_invitation
      match = [workspace_id, client_id, project_intake_id] ==
              [project_invitation.workspace_id, project_invitation.client_id,
               project_invitation.project_intake_id]
      errors.add(:project_invitation, "does not match tenant scope") unless match
    end

    def only_revoke
      return if (changes_to_save.keys - ["updated_at"]) == ["status"] && status == "revoked"
      errors.add(:base, "Only access revocation is allowed")
      throw :abort
    end

    def prevent_destroy
      errors.add(:base, "Client access receipt must be retained")
      throw :abort
    end
  end
end
