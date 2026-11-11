class CreateStudioOfflineRunLedger < ActiveRecord::Migration[8.1]
  def change
    create_table :studio_offline_runs do |t|
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :actor_user_id, null: false
      t.integer :version, null: false
      t.string :purpose, limit: 32, null: false
      t.string :input_fingerprint, limit: 64, null: false
      t.jsonb :output_payload, default: {}, null: false
      t.string :event_digest, limit: 64, null: false
      t.datetime :recorded_at, null: false
      t.timestamps
    end
    add_index :studio_offline_runs, [:project_intake_id, :version], unique: true,
              name: "idx_studio_offline_runs_version"
    add_index :studio_offline_runs, [:workspace_id, :client_id, :project_intake_id, :id],
              name: "idx_studio_offline_runs_scope"
    add_index :studio_offline_runs, [:id, :workspace_id, :client_id, :project_intake_id],
              unique: true, name: "idx_studio_offline_runs_scoped_reference"
    add_foreign_key :studio_offline_runs, :workspaces
    add_foreign_key :studio_offline_runs, :clients,
                    column: [:client_id, :workspace_id], primary_key: [:id, :workspace_id],
                    name: "fk_studio_offline_runs_scoped_client"
    add_foreign_key :studio_offline_runs, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_studio_offline_runs_scoped_intake"
    add_foreign_key :studio_offline_runs, :users, column: :actor_user_id
    add_check_constraint :studio_offline_runs, "version BETWEEN 1 AND 25",
                         name: "chk_studio_offline_run_version"
    add_check_constraint :studio_offline_runs,
                         "purpose IN ('clarify', 'source_outline', 'document_proposal')",
                         name: "chk_studio_offline_run_purpose"
    add_check_constraint :studio_offline_runs, "jsonb_typeof(output_payload) = 'object'",
                         name: "chk_studio_offline_run_payload"
    add_check_constraint :studio_offline_runs,
                         %q(input_fingerprint ~ '^[0-9a-f]{64}$' AND event_digest ~ '^[0-9a-f]{64}$'),
                         name: "chk_studio_offline_run_digests"

    create_table :studio_offline_run_reviews do |t|
      t.bigint :studio_offline_run_id, null: false
      t.bigint :workspace_id, null: false
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :reviewer_user_id, null: false
      t.string :decision, limit: 28, null: false
      t.string :run_digest, limit: 64, null: false
      t.string :event_digest, limit: 64, null: false
      t.datetime :recorded_at, null: false
      t.timestamps
    end
    add_index :studio_offline_run_reviews, :studio_offline_run_id,
              unique: true, name: "idx_studio_offline_one_review"
    add_index :studio_offline_run_reviews, [:workspace_id, :client_id, :project_intake_id],
              name: "idx_studio_offline_review_scope"
    add_foreign_key :studio_offline_run_reviews, :workspaces
    add_foreign_key :studio_offline_run_reviews, :studio_offline_runs,
                    column: [:studio_offline_run_id, :workspace_id, :client_id, :project_intake_id],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id],
                    name: "fk_studio_offline_review_run_scope"
    add_foreign_key :studio_offline_run_reviews, :users, column: :reviewer_user_id
    add_check_constraint :studio_offline_run_reviews,
                         "decision IN ('reviewed_synthetic','discarded_synthetic')",
                         name: "chk_studio_offline_review_decision"
    add_check_constraint :studio_offline_run_reviews,
                         %q(run_digest ~ '^[0-9a-f]{64}$' AND event_digest ~ '^[0-9a-f]{64}$'),
                         name: "chk_studio_offline_review_digests"
  end
end
