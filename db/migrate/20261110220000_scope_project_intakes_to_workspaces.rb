class ScopeProjectIntakesToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    # Legacy RC-031/RC-034 owner-only synthetic intakes remain unassigned.
    # Never map them to a client without individually verified authorization.
    add_reference :project_intakes, :workspace, null: true, foreign_key: true
    add_column :project_intakes, :client_id, :bigint
    add_index :project_intakes, [:client_id, :workspace_id],
              name: "idx_project_intakes_client_workspace"

    add_check_constraint :project_intakes,
                         "client_id IS NULL OR workspace_id IS NOT NULL",
                         name: "chk_project_intakes_client_needs_workspace"
    # Matches the Stage-1 clients unique composite index; reject mismatched
    # tenant even for insert_all/SQL bypass of model validations.
    add_foreign_key :project_intakes, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_project_intakes_scoped_client"
  end
end
