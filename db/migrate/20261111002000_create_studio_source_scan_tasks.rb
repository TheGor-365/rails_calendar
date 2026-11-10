class CreateStudioSourceScanTasks < ActiveRecord::Migration[8.1]
  def change
    # One durable task per synthetic quarantine blob; tenant identity is
    # enforced in PostgreSQL even if Rails-level checks were bypassed.
    add_index :project_source_blobs, [:id, :workspace_id],
              unique: true, name: "idx_project_source_blobs_scan_task_tenant"

    create_table :studio_source_scan_tasks do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :project_source_blob_id, null: false
      t.string :state, limit: 24, null: false, default: "queued"
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at, null: false
      t.string :last_error_code, limit: 32
      t.datetime :finished_at
      t.timestamps
    end

    add_index :studio_source_scan_tasks, :project_source_blob_id, unique: true,
              name: "idx_studio_scan_task_one_per_blob"
    add_index :studio_source_scan_tasks,
              [:workspace_id, :state, :next_attempt_at, :id],
              name: "idx_studio_scan_task_due"
    add_foreign_key :studio_source_scan_tasks, :project_source_blobs,
                    column: [:project_source_blob_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_studio_scan_task_blob_tenant"
    add_check_constraint :studio_source_scan_tasks,
                         "state IN ('queued','retry_wait','complete_clean','complete_infected','exhausted','expired','cancelled')",
                         name: "chk_studio_scan_task_state"
    add_check_constraint :studio_source_scan_tasks,
                         "attempts BETWEEN 0 AND 3",
                         name: "chk_studio_scan_task_attempts"
    add_check_constraint :studio_source_scan_tasks,
                         "last_error_code IS NULL OR last_error_code = 'scan_denied'",
                         name: "chk_studio_scan_task_error"
    add_check_constraint :studio_source_scan_tasks,
                         "(state IN ('queued','retry_wait')) = (finished_at IS NULL)",
                         name: "chk_studio_scan_task_finish"
  end
end
