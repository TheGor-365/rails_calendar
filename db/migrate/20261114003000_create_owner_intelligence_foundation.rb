class CreateOwnerIntelligenceFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.references :owner_user, null: false, index: { unique: true }, foreign_key: { to_table: :users }
      t.string :name, null: false, default: "My practice", limit: 120
      t.timestamps
    end

    create_table :professional_profiles do |t|
      t.references :workspace, null: false, index: { unique: true }, foreign_key: true
      t.string :onboarding_state, null: false, default: "draft", limit: 20
      t.string :headline, limit: 160
      t.text :private_summary
      t.text :public_summary
      t.jsonb :ai_suggestion, null: false, default: {}
      t.string :ai_input_digest, limit: 64
      t.datetime :ai_suggested_at
      t.timestamps
    end

    create_table :owner_interview_answers do |t|
      t.references :professional_profile, null: false, foreign_key: true
      t.string :section_key, null: false, limit: 12
      t.jsonb :selected_options, null: false, default: []
      t.text :notes
      t.boolean :unsure, null: false, default: false
      t.integer :revision, null: false, default: 1
      t.timestamps
    end
    add_index :owner_interview_answers, [:professional_profile_id, :section_key],
              unique: true, name: "idx_owner_answer_per_section"

    create_table :owner_interview_answer_revisions do |t|
      t.references :owner_interview_answer, null: false, foreign_key: true
      t.integer :revision, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.timestamps
    end
    add_index :owner_interview_answer_revisions, [:owner_interview_answer_id, :revision],
              unique: true, name: "idx_owner_answer_revision_unique"

    create_table :professional_context_snapshots do |t|
      t.references :professional_profile, null: false, foreign_key: true
      t.integer :version, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :digest, limit: 64, null: false
      t.datetime :approved_at, null: false
      t.timestamps
    end
    add_index :professional_context_snapshots, [:professional_profile_id, :version],
              unique: true, name: "idx_owner_context_version"

    create_table :professional_capabilities do |t|
      t.references :professional_profile, null: false, foreign_key: true
      t.integer :snapshot_version, null: false
      t.string :domain, limit: 80, null: false
      t.string :delivery_mode, limit: 20, null: false
      t.string :experience_claim, limit: 20, null: false
      t.string :evidence_status, limit: 24, null: false, default: "self_reported"
      t.string :willingness, limit: 24, null: false
      t.string :privacy_scope, limit: 24, null: false, default: "private"
      t.text :conditions
      t.boolean :review_required, null: false, default: true
      t.timestamps
    end
    add_index :professional_capabilities, [:professional_profile_id, :snapshot_version, :domain],
              unique: true, name: "idx_owner_capability_snapshot"

    create_table :work_policies do |t|
      t.references :professional_profile, null: false, foreign_key: true
      t.integer :snapshot_version, null: false
      t.jsonb :hard_no_go, null: false, default: []
      t.jsonb :work_preferences, null: false, default: []
      t.text :notes
      t.timestamps
    end
    add_index :work_policies, [:professional_profile_id, :snapshot_version],
              unique: true, name: "idx_owner_policy_snapshot"

    # Existing paid client ledger is preserved unchanged; extend to owner AI work.
    add_reference :ai_spend_entries, :professional_profile, null: true, foreign_key: true
    change_column_null :ai_spend_entries, :project_intake_id, true
    add_check_constraint :ai_spend_entries,
      "(project_intake_id IS NOT NULL) <> (professional_profile_id IS NOT NULL)",
      name: "chk_ai_spend_exactly_one_subject"
  end
end
