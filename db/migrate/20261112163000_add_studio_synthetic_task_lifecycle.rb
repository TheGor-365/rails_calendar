# RC-039 Slice G. Additive schema for nonproduction synthetic task lifecycle only.
class AddStudioSyntheticTaskLifecycle < ActiveRecord::Migration[8.1]
  def change
    add_column :studio_synthetic_project_tasks, :state, :string,
               null: false, default: "proposed", limit: 24
    add_column :studio_synthetic_project_tasks, :priority, :integer,
               null: false, default: 3
    add_column :studio_synthetic_project_tasks, :lock_version, :integer,
               null: false, default: 0
    add_check_constraint :studio_synthetic_project_tasks,
                         "state IN ('proposed','ready','in_progress','blocked','completed')",
                         name: "chk_rc039_task_lifecycle_state"
    add_check_constraint :studio_synthetic_project_tasks,
                         "priority BETWEEN 1 AND 5",
                         name: "chk_rc039_task_priority"
    add_check_constraint :studio_synthetic_project_tasks,
                         "lock_version >= 0",
                         name: "chk_rc039_task_lifecycle_version"

    create_table :studio_synthetic_project_task_events do |t|
      t.bigint :studio_synthetic_project_task_id, null: false
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :actor_user_id, null: false
      t.integer :sequence, null: false
      t.string :event_type, null: false, limit: 24
      t.string :from_state, null: false, limit: 24
      t.string :to_state, null: false, limit: 24
      t.integer :from_priority, null: false
      t.integer :to_priority, null: false
      t.datetime :recorded_at, null: false
      t.timestamps
    end
    add_index :studio_synthetic_project_task_events,
              [:studio_synthetic_project_task_id, :sequence],
              unique: true, name: "idx_rc039_task_event_monotonic_version"
    add_index :studio_synthetic_project_task_events,
              [:workspace_id, :client_id, :project_intake_id],
              name: "idx_rc039_task_event_tenant_scope"
    add_foreign_key :studio_synthetic_project_task_events, :users,
                    column: :actor_user_id, name: "fk_rc039_task_event_actor"
    add_foreign_key :studio_synthetic_project_task_events,
                    :studio_synthetic_project_tasks,
                    column: [:studio_synthetic_project_task_id, :workspace_id,
                             :client_id, :project_intake_id],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id],
                    name: "fk_rc039_task_event_tenant_identity"
    add_check_constraint :studio_synthetic_project_task_events,
                         "sequence >= 1 AND from_priority BETWEEN 1 AND 5 AND to_priority BETWEEN 1 AND 5",
                         name: "chk_rc039_task_event_numeric_bounds"
    permitted_edges = <<~SQL
      (event_type = 'transition'
       AND from_priority = to_priority
       AND (
         (from_state = 'proposed' AND to_state = 'ready')
         OR (from_state = 'ready' AND to_state = 'in_progress')
         OR (from_state = 'in_progress' AND to_state IN ('blocked','completed'))
         OR (from_state = 'blocked' AND to_state = 'in_progress')
       ))
       OR (event_type = 'priority_change'
         AND from_state = to_state
         AND from_state <> 'completed'
         AND from_priority <> to_priority)
    SQL
    add_check_constraint :studio_synthetic_project_task_events, permitted_edges,
                         name: "chk_rc039_task_event_allowed_changes"
  end
end
