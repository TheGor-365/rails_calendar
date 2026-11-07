# Independent proposal workspace: no edits or references to owner's consultations.
class CreateProjectIntakeWorkspace < ActiveRecord::Migration[8.1]
  def change
    create_table :project_intakes do |t|
      t.string :title, limit: 120, null: false
      t.string :project_type, limit: 32, null: false
      t.text :goal, null: false
      t.string :status, limit: 32, default: "interviewing", null: false
      t.integer :ai_call_count, default: 0, null: false
      t.datetime :demo_consent_at, null: false
      t.timestamps
    end

    create_table :intake_messages do |t|
      t.references :project_intake, null: false, foreign_key: true
      t.string :role, limit: 16, null: false
      t.text :body, null: false
      t.timestamps
    end
    add_index :intake_messages, [:project_intake_id, :created_at, :id],
              name: "idx_intake_conversation_order"

    create_table :intake_spec_versions do |t|
      t.references :project_intake, null: false, foreign_key: true
      t.integer :version, null: false
      t.jsonb :document, null: false, default: {}
      t.string :source, limit: 16, null: false
      t.datetime :owner_approved_at
      t.datetime :client_reviewed_at
      t.timestamps
    end
    add_index :intake_spec_versions, [:project_intake_id, :version],
              unique: true, name: "idx_intake_spec_immutable_version"

    create_table :intake_ai_quotas do |t|
      t.date :usage_day, null: false
      t.integer :call_count, null: false, default: 0
      t.timestamps
    end
    add_index :intake_ai_quotas, :usage_day, unique: true
  end
end
