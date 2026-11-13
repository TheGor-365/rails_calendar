class CreateAiSpendEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_spend_entries do |t|
      t.references :project_intake, null: false, foreign_key: true
      t.string :operation, limit: 40, null: false
      t.string :model, limit: 64, null: false
      t.string :request_digest, limit: 64, null: false
      t.string :status, limit: 16, default: "reserved", null: false
      t.bigint :reserved_ticks, null: false
      t.bigint :charged_ticks
      t.jsonb :result, null: false, default: {}
      t.jsonb :usage, null: false, default: {}
      t.string :provider_response_id, limit: 128
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :ai_spend_entries, :request_digest, unique: true
    add_index :ai_spend_entries, [:project_intake_id, :created_at]
    add_index :ai_spend_entries, [:status, :created_at]
    add_check_constraint :ai_spend_entries, "reserved_ticks >= 0 AND (charged_ticks IS NULL OR charged_ticks >= 0)", name: "chk_ai_spend_ticks_nonnegative"
    add_check_constraint :ai_spend_entries, "status IN ('reserved', 'settled', 'uncertain', 'cancelled')", name: "chk_ai_spend_status"
  end
end
