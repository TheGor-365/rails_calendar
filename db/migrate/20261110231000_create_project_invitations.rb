class CreateProjectInvitations < ActiveRecord::Migration[8.1]
  def change
    # Stage 3 slice B: owner-issued, NON-REDEEMABLE invitations. A token
    # alone is never proof of identity; client auth has not been implemented.
    create_table :project_invitations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.references :issued_by, null: false, foreign_key: { to_table: :users }
      t.string :recipient_digest, limit: 64, null: false
      t.string :token_digest, limit: 64, null: false
      t.string :role, limit: 20, default: "reviewer", null: false
      t.string :status, limit: 20, default: "pending", null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :project_invitations, :token_digest, unique: true,
              name: "idx_project_invitations_unique_token"
    add_index :project_invitations, [:workspace_id, :client_id, :project_intake_id],
              name: "idx_project_invitations_tenant_scope"
    add_foreign_key :project_invitations, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_project_invitations_client_tenant"
    add_foreign_key :project_invitations, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_project_invitations_intake_tenant"
    add_check_constraint :project_invitations,
                         "role = 'reviewer'", name: "chk_project_invitations_role"
    add_check_constraint :project_invitations,
                         "status IN ('pending', 'revoked')",
                         name: "chk_project_invitations_no_granted_access"
    add_check_constraint :project_invitations,
                         %q(token_digest ~ '^[0-9a-f]{64}$'),
                         name: "chk_project_invitations_token_digest"
    add_check_constraint :project_invitations,
                         %q(recipient_digest ~ '^[0-9a-f]{64}$'),
                         name: "chk_project_invitations_recipient_digest"
    add_check_constraint :project_invitations,
                         "expires_at > created_at AND expires_at <= created_at + interval '72 hours'",
                         name: "chk_project_invitations_expiry_window"
  end
end
