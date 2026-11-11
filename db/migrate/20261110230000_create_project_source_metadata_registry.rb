class CreateProjectSourceMetadataRegistry < ActiveRecord::Migration[8.1]
  def change
    # Stage 3, slice A: metadata only. No original filenames, raw bytes,
    # object keys, attachments, public routes, or background uploads.
    # Never bind legacy nullable-scope intakes to a real client.
    add_index :project_intakes, [:id, :workspace_id, :client_id],
              unique: true, name: "idx_project_intakes_scoped_source_reference"

    create_table :project_sources do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.string :source_sha256, limit: 64, null: false
      t.integer :byte_size, null: false
      t.string :source_format, limit: 20, null: false
      t.string :parser_version, limit: 32, null: false
      t.string :state, limit: 32, default: "metadata_only", null: false
      t.timestamps
    end
    add_index :project_sources, [:workspace_id, :client_id, :project_intake_id],
              name: "idx_project_sources_tenant_scope"
    add_index :project_sources, [:project_intake_id, :source_sha256, :parser_version],
              unique: true, name: "idx_project_sources_idempotency"

    add_foreign_key :project_sources, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_project_sources_client_tenant"
    add_foreign_key :project_sources, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_project_sources_intake_tenant"
    add_check_constraint :project_sources,
                         "state = 'metadata_only'",
                         name: "chk_project_sources_no_release_before_privacy_gate"
    add_check_constraint :project_sources,
                         "byte_size BETWEEN 1 AND 262144",
                         name: "chk_project_sources_preview_size"
    add_check_constraint :project_sources,
                         %q(source_sha256 ~ '^[0-9a-f]{64}$'),
                         name: "chk_project_sources_sha256"
    add_check_constraint :project_sources,
                         "source_format IN ('markdown', 'text', 'json')",
                         name: "chk_project_sources_format"
  end
end
