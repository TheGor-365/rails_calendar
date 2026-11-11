class CreateStudioMaintenanceRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :studio_maintenance_runs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :kind, null: false, limit: 16
      t.string :state, null: false, limit: 16, default: "running"
      t.bigint :slot, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string :error_code, limit: 32
      t.jsonb :result_summary, null: false, default: {}
      t.timestamps
    end
    add_index :studio_maintenance_runs, [:workspace_id, :kind, :slot],
              unique: true, name: "idx_studio_maintenance_unique_slot"
    add_index :studio_maintenance_runs, [:workspace_id, :kind, :state],
              name: "idx_studio_maintenance_live"
    add_check_constraint :studio_maintenance_runs,
                         "kind IN ('health', 'scan', 'retention', 'inventory')",
                         name: "chk_studio_maintenance_kind"
    add_check_constraint :studio_maintenance_runs,
                         "state IN ('running', 'succeeded', 'failed')",
                         name: "chk_studio_maintenance_state"
    add_check_constraint :studio_maintenance_runs,
                         "(state = 'running') = (finished_at IS NULL)",
                         name: "chk_studio_maintenance_finished"
    add_check_constraint :studio_maintenance_runs,
                         "error_code IS NULL OR error_code = 'operation_failed'",
                         name: "chk_studio_maintenance_error"
    add_check_constraint :studio_maintenance_runs,
                         "jsonb_typeof(result_summary) = 'object'",
                         name: "chk_studio_maintenance_summary"
  end
end
