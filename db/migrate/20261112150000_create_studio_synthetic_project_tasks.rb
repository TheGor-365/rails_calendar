# RC-039 Slice F: fictional-only task graph. No customer content or live work.
class CreateStudioSyntheticProjectTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :studio_synthetic_project_tasks do |t|
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :created_by_id, null: false
      t.string :task_key, null: false, limit: 40
      t.timestamps
    end
    add_index :studio_synthetic_project_tasks, [:project_intake_id, :task_key],
              unique: true, name: "idx_rc039_one_task_per_project_key"
    add_index :studio_synthetic_project_tasks,
              [:id, :workspace_id, :client_id, :project_intake_id],
              unique: true, name: "idx_rc039_task_tenant_identity"
    add_foreign_key :studio_synthetic_project_tasks, :workspaces
    add_foreign_key :studio_synthetic_project_tasks, :users, column: :created_by_id
    add_foreign_key :studio_synthetic_project_tasks, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_rc039_task_scoped_client"
    add_foreign_key :studio_synthetic_project_tasks, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_rc039_task_scoped_intake"
    add_check_constraint :studio_synthetic_project_tasks,
                         "task_key IN ('scope_review','solution_design','rails_implementation','interface_implementation','quality_verification','handoff_preparation')",
                         name: "chk_rc039_task_fixed_catalog"

    create_table :studio_synthetic_project_task_dependencies do |t|
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :dependent_task_id, null: false
      t.bigint :prerequisite_task_id, null: false
      t.bigint :created_by_id, null: false
      t.timestamps
    end
    add_index :studio_synthetic_project_task_dependencies,
              [:dependent_task_id, :prerequisite_task_id],
              unique: true, name: "idx_rc039_unique_task_dependency"
    add_index :studio_synthetic_project_task_dependencies,
              [:workspace_id, :client_id, :project_intake_id],
              name: "idx_rc039_dependency_tenant_scope"
    add_foreign_key :studio_synthetic_project_task_dependencies, :users,
                    column: :created_by_id, name: "fk_rc039_dependency_actor"
    add_foreign_key :studio_synthetic_project_task_dependencies,
                    :studio_synthetic_project_tasks,
                    column: [:dependent_task_id, :workspace_id, :client_id, :project_intake_id],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id],
                    name: "fk_rc039_dependency_scoped_task"
    add_foreign_key :studio_synthetic_project_task_dependencies,
                    :studio_synthetic_project_tasks,
                    column: [:prerequisite_task_id, :workspace_id, :client_id, :project_intake_id],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id],
                    name: "fk_rc039_dependency_scoped_prerequisite"
    add_check_constraint :studio_synthetic_project_task_dependencies,
                         "dependent_task_id <> prerequisite_task_id",
                         name: "chk_rc039_dependency_no_self_reference"
  end
end
