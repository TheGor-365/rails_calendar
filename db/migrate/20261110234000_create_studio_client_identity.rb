class CreateStudioClientIdentity < ActiveRecord::Migration[8.1]
  def change
    create_table :studio_client_accounts do |t|
      t.string :email_digest, limit: 64, null: false
      t.string :password_digest, null: false
      t.string :status, limit: 16, null: false, default: "active"
      t.timestamps
    end
    add_index :studio_client_accounts, :email_digest, unique: true,
              name: "idx_studio_client_accounts_email_digest"
    add_check_constraint :studio_client_accounts, %q(email_digest ~ '^[0-9a-f]{64}$'),
                         name: "chk_studio_client_account_digest"
    add_check_constraint :studio_client_accounts, "status IN ('active', 'suspended')",
                         name: "chk_studio_client_account_status"

    create_table :studio_client_sessions do |t|
      t.references :studio_client_account, null: false,
                   foreign_key: true, index: { name: "idx_studio_client_sessions_account" }
      t.string :token_digest, limit: 64, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :studio_client_sessions, :token_digest, unique: true,
              name: "idx_studio_client_sessions_token"
    add_check_constraint :studio_client_sessions, %q(token_digest ~ '^[0-9a-f]{64}$'),
                         name: "chk_studio_client_session_digest"
    add_check_constraint :studio_client_sessions,
                         "expires_at > created_at AND expires_at <= created_at + interval '8 hours'",
                         name: "chk_studio_client_session_expiry"

    # One invitation can be accepted once, even under concurrent requests.
    add_index :project_invitations, [:id, :workspace_id, :client_id, :project_intake_id],
              unique: true, name: "idx_project_invitation_client_grant_scope"

    create_table :studio_client_project_grants do |t|
      t.references :studio_client_account, null: false,
                   foreign_key: true, index: { name: "idx_studio_grants_account" }
      t.bigint :project_invitation_id, null: false
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.string :role, limit: 20, null: false, default: "reviewer"
      t.string :status, limit: 16, null: false, default: "active"
      t.string :consent_policy, limit: 32, null: false
      t.datetime :consented_at, null: false
      t.datetime :accepted_at, null: false
      t.timestamps
    end
    add_index :studio_client_project_grants, :project_invitation_id,
              unique: true, name: "idx_studio_grants_single_use_invitation"
    add_index :studio_client_project_grants,
              [:studio_client_account_id, :workspace_id, :client_id, :project_intake_id],
              name: "idx_studio_grants_account_tenant"
    add_foreign_key :studio_client_project_grants, :project_invitations,
                    column: [:project_invitation_id, :workspace_id, :client_id, :project_intake_id],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id],
                    name: "fk_studio_grants_invitation_tenant"
    add_foreign_key :studio_client_project_grants, :clients,
                    column: [:client_id, :workspace_id], primary_key: [:id, :workspace_id],
                    name: "fk_studio_grants_client_tenant"
    add_foreign_key :studio_client_project_grants, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_studio_grants_intake_tenant"
    add_check_constraint :studio_client_project_grants,
                         "role = 'reviewer'", name: "chk_studio_grants_reviewer_only"
    add_check_constraint :studio_client_project_grants,
                         "status IN ('active','revoked')", name: "chk_studio_grants_status"
    add_check_constraint :studio_client_project_grants,
                         "consent_policy = 'studio_review_v1'",
                         name: "chk_studio_grants_consent_policy"
    add_check_constraint :studio_client_project_grants,
                         "consented_at <= accepted_at",
                         name: "chk_studio_grants_consent_first"
  end
end
