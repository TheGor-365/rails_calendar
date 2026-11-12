class CreateStudioAiPolicyRevisions < ActiveRecord::Migration[8.1]
  def change
    # Composite reference blocks cross-tenant policy revision inserts.
    add_index :studio_ai_policies, [:id, :workspace_id], unique: true,
              name: "idx_studio_ai_policy_scoped_reference"

    create_table :studio_ai_policy_revisions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :studio_ai_policy_id, null: false
      t.bigint :project_intake_id
      t.bigint :actor_user_id
      t.integer :revision, null: false
      t.string :action, limit: 16, null: false
      t.string :origin, limit: 32, null: false
      t.jsonb :settings, null: false, default: {}
      t.string :previous_digest, limit: 64, null: false
      t.string :event_digest, limit: 64, null: false
      t.datetime :recorded_at, null: false
      t.timestamps
    end
    add_index :studio_ai_policy_revisions, [:studio_ai_policy_id, :revision],
              unique: true, name: "idx_studio_ai_policy_revisions_sequence"
    add_index :studio_ai_policy_revisions, [:workspace_id, :project_intake_id, :id],
              name: "idx_studio_ai_policy_revisions_scope"
    add_foreign_key :studio_ai_policy_revisions, :studio_ai_policies,
                    column: [:studio_ai_policy_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_studio_ai_policy_revision_scoped_policy"
    add_foreign_key :studio_ai_policy_revisions, :project_intakes,
                    column: [:project_intake_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_studio_ai_policy_revision_scoped_intake"
    add_foreign_key :studio_ai_policy_revisions, :users,
                    column: :actor_user_id, name: "fk_studio_ai_policy_revision_actor"
    add_check_constraint :studio_ai_policy_revisions, "revision >= 1",
                         name: "chk_studio_ai_policy_revision_positive"
    add_check_constraint :studio_ai_policy_revisions,
                         "action IN ('created', 'updated')",
                         name: "chk_studio_ai_policy_revision_action"
    add_check_constraint :studio_ai_policy_revisions,
                         "origin IN ('owner_ui', 'internal_unattributed')",
                         name: "chk_studio_ai_policy_revision_origin"
    add_check_constraint :studio_ai_policy_revisions,
                         "jsonb_typeof(settings) = 'object'",
                         name: "chk_studio_ai_policy_revision_settings"
    add_check_constraint :studio_ai_policy_revisions,
                         %q(previous_digest ~ '^[0-9a-f]{64}$' AND event_digest ~ '^[0-9a-f]{64}$'),
                         name: "chk_studio_ai_policy_revision_digest"
  end
end
