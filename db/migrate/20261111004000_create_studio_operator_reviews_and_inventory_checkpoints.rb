class CreateStudioOperatorReviewsAndInventoryCheckpoints < ActiveRecord::Migration[8.1]
  def change
    add_index :studio_maintenance_runs, [:id, :workspace_id],
              unique: true, name: "idx_studio_maintenance_run_tenant_reference"

    create_table :studio_operator_reviews do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :studio_maintenance_run_id, null: false
      t.references :reviewed_by, null: false, foreign_key: { to_table: :users }
      t.string :reason_code, limit: 40, null: false
      t.datetime :reviewed_at, null: false
      t.timestamps
    end
    add_index :studio_operator_reviews, :studio_maintenance_run_id,
              unique: true, name: "idx_studio_operator_reviews_one_per_run"
    add_foreign_key :studio_operator_reviews, :studio_maintenance_runs,
                    column: [:studio_maintenance_run_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_studio_operator_review_run_tenant"
    add_check_constraint :studio_operator_reviews,
      "reason_code IN ('health_inspected', 'inventory_inspected', 'scan_tasks_inspected', 'retention_objects_inspected')",
      name: "chk_studio_operator_review_reason"

    create_table :studio_inventory_checkpoints do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :state, limit: 16, null: false, default: "listing"
      t.string :config_digest, limit: 64, null: false
      t.text :encrypted_cursor
      t.jsonb :seen_cursor_digests, null: false, default: []
      t.jsonb :counts, null: false, default: {}
      t.integer :pages_scanned, null: false, default: 0
      t.bigint :last_db_blob_id, null: false, default: 0
      t.bigint :db_target_max_id, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :finished_at
      t.string :error_code, limit: 32
      t.timestamps
    end
    add_index :studio_inventory_checkpoints, [:workspace_id, :state],
              name: "idx_studio_inventory_state"
    add_index :studio_inventory_checkpoints, :workspace_id,
              unique: true, where: "state IN ('listing','checking')",
              name: "idx_studio_inventory_one_active_per_workspace"
    add_check_constraint :studio_inventory_checkpoints,
      "state IN ('listing','checking','completed','failed')",
      name: "chk_studio_inventory_checkpoint_state"
    add_check_constraint :studio_inventory_checkpoints,
      "(state IN ('listing','checking')) = (finished_at IS NULL)",
      name: "chk_studio_inventory_checkpoint_terminal"
    add_check_constraint :studio_inventory_checkpoints,
      "pages_scanned BETWEEN 0 AND 10000 AND last_db_blob_id >= 0 AND db_target_max_id >= 0",
      name: "chk_studio_inventory_checkpoint_progress"
    add_check_constraint :studio_inventory_checkpoints,
      "jsonb_typeof(counts) = 'object' AND jsonb_typeof(seen_cursor_digests) = 'array'",
      name: "chk_studio_inventory_checkpoint_json"
    add_check_constraint :studio_inventory_checkpoints,
      %q(config_digest ~ '^[0-9a-f]{64}$'),
      name: "chk_studio_inventory_config_digest"
    add_check_constraint :studio_inventory_checkpoints,
      "error_code IS NULL OR error_code IN ('expired','manual_stop')",
      name: "chk_studio_inventory_checkpoint_error"
  end
end
