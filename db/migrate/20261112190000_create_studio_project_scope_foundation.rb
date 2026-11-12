# RC-039 Slice I1. Schema for a future real Project, but admission is test-only
# until client identity, acceptance UI, tenant RBAC and privacy are reviewed.
class CreateStudioProjectScopeFoundation < ActiveRecord::Migration[8.1]
  def change
    # A revision must always belong to the specified intake, even for raw SQL.
    add_index :intake_spec_versions, [:id, :project_intake_id],
              unique: true, name: "idx_rc039_i_spec_intake_identity"
    add_index :studio_client_project_grants,
              [:id, :workspace_id, :client_id, :project_intake_id, :studio_client_account_id],
              unique: true, name: "idx_rc039_i_grant_scope_identity"

    create_table :studio_project_scope_acceptances do |t|
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :intake_spec_version_id, null: false
      t.bigint :studio_client_project_grant_id, null: false
      t.bigint :studio_client_account_id, null: false
      t.string :document_sha256, null: false, limit: 64
      t.datetime :accepted_at, null: false
      t.timestamps
    end
    add_index :studio_project_scope_acceptances, :project_intake_id,
              unique: true, name: "idx_rc039_i_one_scope_receipt_per_intake"
    add_index :studio_project_scope_acceptances,
              [:id, :workspace_id, :client_id, :project_intake_id,
               :intake_spec_version_id, :document_sha256],
              unique: true, name: "idx_rc039_i_acceptance_scope_identity"
    add_foreign_key :studio_project_scope_acceptances, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_rc039_i_acceptance_scoped_client"
    add_foreign_key :studio_project_scope_acceptances, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_rc039_i_acceptance_scoped_intake"
    add_foreign_key :studio_project_scope_acceptances, :intake_spec_versions,
                    column: [:intake_spec_version_id, :project_intake_id],
                    primary_key: [:id, :project_intake_id],
                    name: "fk_rc039_i_acceptance_scoped_spec"
    add_foreign_key :studio_project_scope_acceptances, :studio_client_project_grants,
                    column: [:studio_client_project_grant_id, :workspace_id, :client_id,
                             :project_intake_id, :studio_client_account_id],
                    primary_key: [:id, :workspace_id, :client_id,
                                  :project_intake_id, :studio_client_account_id],
                    name: "fk_rc039_i_acceptance_scoped_grant"
    add_check_constraint :studio_project_scope_acceptances,
                         %q(document_sha256 ~ '^[0-9a-f]{64}$'),
                         name: "chk_rc039_i_acceptance_digest"

    create_table :studio_projects do |t|
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :intake_spec_version_id, null: false
      t.bigint :studio_project_scope_acceptance_id, null: false
      t.bigint :created_by_id, null: false
      t.string :document_sha256, null: false, limit: 64
      t.string :status, null: false, default: "internal_scope_locked", limit: 32
      t.timestamps
    end
    add_index :studio_projects, :project_intake_id,
              unique: true, name: "idx_rc039_i_one_project_per_intake"
    add_index :studio_projects, [:workspace_id, :client_id, :project_intake_id],
              name: "idx_rc039_i_project_tenant"
    add_foreign_key :studio_projects, :users, column: :created_by_id,
                    name: "fk_rc039_i_project_owner"
    add_foreign_key :studio_projects, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_rc039_i_project_scoped_intake"
    add_foreign_key :studio_projects, :studio_project_scope_acceptances,
                    column: [:studio_project_scope_acceptance_id, :workspace_id,
                             :client_id, :project_intake_id, :intake_spec_version_id,
                             :document_sha256],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id,
                                  :intake_spec_version_id, :document_sha256],
                    name: "fk_rc039_i_project_exact_acceptance"
    add_check_constraint :studio_projects,
                         "status = 'internal_scope_locked'",
                         name: "chk_rc039_i_project_not_live"
    add_check_constraint :studio_projects,
                         %q(document_sha256 ~ '^[0-9a-f]{64}$'),
                         name: "chk_rc039_i_project_digest"
  end
end
