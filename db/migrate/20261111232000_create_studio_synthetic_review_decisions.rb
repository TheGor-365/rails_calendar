class CreateStudioSyntheticReviewDecisions < ActiveRecord::Migration[8.1]
  def change
    # Synthetic metadata-only triage. NO source content, comment text or
    # real-client approvals may be persisted through this primitive.
    create_table :studio_synthetic_review_decisions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :client_id, null: false
      t.bigint :project_intake_id, null: false
      t.bigint :baseline_source_id, null: false
      t.bigint :incoming_source_id, null: false
      t.references :reviewed_by, null: false, foreign_key: { to_table: :users }
      t.string :comparison_digest, null: false, limit: 64
      t.string :incoming_fact_id, null: false, limit: 32
      t.string :candidate_state, null: false, limit: 16
      t.string :resolution, null: false, limit: 24
      t.datetime :reviewed_at, null: false
      t.timestamps
    end

    add_index :studio_synthetic_review_decisions,
              [:project_intake_id, :comparison_digest, :incoming_fact_id],
              unique: true, name: "idx_synthetic_review_one_decision_per_candidate"
    add_foreign_key :studio_synthetic_review_decisions, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_studio_synthetic_review_client"
    add_foreign_key :studio_synthetic_review_decisions, :project_intakes,
                    column: [:project_intake_id, :workspace_id, :client_id],
                    primary_key: [:id, :workspace_id, :client_id],
                    name: "fk_studio_synthetic_review_intake"
    add_foreign_key :studio_synthetic_review_decisions, :project_sources,
                    column: [:baseline_source_id, :workspace_id, :client_id, :project_intake_id],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id],
                    name: "fk_studio_synthetic_review_baseline"
    add_foreign_key :studio_synthetic_review_decisions, :project_sources,
                    column: [:incoming_source_id, :workspace_id, :client_id, :project_intake_id],
                    primary_key: [:id, :workspace_id, :client_id, :project_intake_id],
                    name: "fk_studio_synthetic_review_incoming"

    add_check_constraint :studio_synthetic_review_decisions,
                         "candidate_state IN ('new','corroborates','conflicts','unknown')",
                         name: "chk_studio_synthetic_review_candidate_state"
    add_check_constraint :studio_synthetic_review_decisions,
                         "resolution IN ('needs_information','retain_for_review','exclude_from_draft')",
                         name: "chk_studio_synthetic_review_resolution"
    add_check_constraint :studio_synthetic_review_decisions,
                         "candidate_state IN ('new','corroborates') OR resolution <> 'retain_for_review'",
                         name: "chk_studio_synthetic_review_no_unresolved_accept"
    add_check_constraint :studio_synthetic_review_decisions,
                         %q(comparison_digest ~ '^[0-9a-f]{64}$' AND incoming_fact_id ~ '^fact-[0-9a-f]{24}$'),
                         name: "chk_studio_synthetic_review_provenance"
  end
end
