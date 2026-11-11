class CreateStudioSyntheticProjectCards < ActiveRecord::Migration[8.1]
  def change
    # RC-039 Slice B: no free text, real client tasks or production writes.
    # Database-level tenant boundaries protect even direct SQL inserts.
    create_table :studio_synthetic_project_cards do |t|
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :created_by_id, null: false
      t.string :artifact_key, limit: 32, null: false
      t.string :state, limit: 20, null: false, default: "backlog"
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :studio_synthetic_project_cards, [:project_intake_id, :artifact_key],
              unique: true, name: "idx_rc039_one_synthetic_card_per_artifact"
    add_index :studio_synthetic_project_cards,
              [:id, :workspace_id, :client_id, :project_intake_id],
              unique: true, name: "idx_rc039_synthetic_card_tenant_reference"
    add_foreign_key :studio_synthetic_project_cards, :workspaces
    add_foreign_key :studio_synthetic_project_cards, :users, column: :created_by_id
    add_foreign_key :studio_synthetic_project_cards, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_rc039_card_scoped_client"
    add_foreign_key :studio_synthetic_project_cards, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_rc039_card_scoped_intake"
    add_check_constraint :studio_synthetic_project_cards,
                         "state IN ('backlog','in_review','on_hold')",
                         name: "chk_rc039_card_no_approved_state"
    add_check_constraint :studio_synthetic_project_cards,
                         "lock_version >= 0",
                         name: "chk_rc039_card_lock_version"
    add_check_constraint :studio_synthetic_project_cards,
                         "artifact_key IN ('discovery_brief','clarification_questions','requirements_spec','architecture','qa_plan','full_roadmap','financial_scenarios','pitch_deck','handoff_bundle')",
                         name: "chk_rc039_card_catalog"

    create_table :studio_synthetic_project_card_transitions do |t|
      t.bigint :studio_synthetic_project_card_id, null: false
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :actor_user_id, null: false
      t.integer :sequence, null: false
      t.string :from_state, limit: 20, null: false
      t.string :to_state, limit: 20, null: false
      t.datetime :recorded_at, null: false
      t.timestamps
    end
    add_index :studio_synthetic_project_card_transitions,
              [:studio_synthetic_project_card_id, :sequence],
              unique: true, name: "idx_rc039_card_transition_sequence"
    add_index :studio_synthetic_project_card_transitions,
              [:workspace_id, :client_id, :project_intake_id],
              name: "idx_rc039_card_transition_tenant_scope"
    add_foreign_key :studio_synthetic_project_card_transitions, :users,
                    column: :actor_user_id, name: "fk_rc039_card_transition_actor"
    add_foreign_key :studio_synthetic_project_card_transitions,
                    :studio_synthetic_project_cards,
                    column: [:studio_synthetic_project_card_id, :workspace_id,
                             :client_id, :project_intake_id],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id],
                    name: "fk_rc039_card_transition_scope"
    add_check_constraint :studio_synthetic_project_card_transitions, "sequence >= 1",
                         name: "chk_rc039_card_transition_sequence"
    add_check_constraint :studio_synthetic_project_card_transitions,
                         %q((from_state = 'backlog' AND to_state = 'in_review') OR
                            (from_state = 'in_review' AND to_state IN ('backlog','on_hold')) OR
                            (from_state = 'on_hold' AND to_state IN ('backlog','in_review'))),
                         name: "chk_rc039_card_transition_allowed_edges"
  end
end
