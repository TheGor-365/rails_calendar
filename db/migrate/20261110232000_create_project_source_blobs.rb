class CreateProjectSourceBlobs < ActiveRecord::Migration[8.1]
  def change
    # Additive only. Existing metadata rows remain unchanged.
    add_index :project_sources, [:id, :workspace_id, :client_id, :project_intake_id],
              unique: true, name: "idx_project_sources_blob_scope"

    create_table :project_source_blobs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :project_source_id, null: false
      t.string :object_key, limit: 66, null: false
      t.string :scan_state, limit: 24, default: "quarantined", null: false
      t.string :scanner_engine, limit: 80
      t.string :scan_sha256, limit: 64
      t.datetime :scanned_at
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :project_source_blobs, :project_source_id, unique: true,
              name: "idx_project_source_blobs_one_per_source"
    add_index :project_source_blobs, :object_key, unique: true,
              name: "idx_project_source_blobs_private_object_key"
    add_index :project_source_blobs, [:workspace_id, :client_id, :project_intake_id],
              name: "idx_project_source_blobs_tenant_scope"
    add_foreign_key :project_source_blobs, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_project_source_blobs_client_tenant"
    add_foreign_key :project_source_blobs, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_project_source_blobs_intake_tenant"
    add_foreign_key :project_source_blobs, :project_sources,
                    column: [:project_source_id, :workspace_id, :client_id, :project_intake_id],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id],
                    name: "fk_project_source_blobs_source_tenant"
    add_check_constraint :project_source_blobs,
                         "scan_state IN ('quarantined', 'clean', 'infected', 'failed', 'revoked')",
                         name: "chk_project_source_blob_scan_state"
    add_check_constraint :project_source_blobs,
                         "scan_state <> 'clean' OR (scanner_engine IS NOT NULL AND scan_sha256 IS NOT NULL AND scanned_at IS NOT NULL)",
                         name: "chk_project_source_blob_clean_requires_attestation"
    add_check_constraint :project_source_blobs,
                         %q(object_key ~ '^q/[0-9a-f]{64}$'),
                         name: "chk_project_source_blob_random_key"
    add_check_constraint :project_source_blobs,
                         "scan_sha256 IS NULL OR scan_sha256 ~ '^[0-9a-f]{64}$'",
                         name: "chk_project_source_blob_scan_sha"
    add_check_constraint :project_source_blobs,
                         "expires_at > created_at AND expires_at <= created_at + interval '8 days'",
                         name: "chk_project_source_blob_expiry_window"
  end
end
