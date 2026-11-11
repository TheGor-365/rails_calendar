class CreateStudioAiExecutionReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :studio_ai_execution_receipts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :project_intake_id, null: false
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :request_fingerprint, limit: 64, null: false
      t.string :purpose, limit: 32, null: false
      t.string :registry_key, limit: 64, null: false
      t.string :state, limit: 24, null: false, default: "completed_offline"
      t.integer :tokens_reserved, null: false, default: 0
      t.integer :tokens_used, null: false, default: 0
      t.decimal :usd_reserved, precision: 12, scale: 6, null: false, default: 0
      t.decimal :usd_used, precision: 12, scale: 6, null: false, default: 0
      t.datetime :completed_at, null: false
      t.timestamps
    end

    add_index :studio_ai_execution_receipts,
              [:workspace_id, :project_intake_id, :request_fingerprint],
              unique: true, name: "idx_studio_ai_receipt_idempotent"
    add_foreign_key :studio_ai_execution_receipts, :project_intakes,
                    column: [:project_intake_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_studio_ai_receipt_intake_tenant"
    add_check_constraint :studio_ai_execution_receipts,
                         "state = 'completed_offline' AND purpose = 'document_plan' AND registry_key = 'offline_document_plan_v1'",
                         name: "chk_studio_ai_receipt_offline_only"
    add_check_constraint :studio_ai_execution_receipts,
                         "tokens_reserved = 0 AND tokens_used = 0 AND usd_reserved = 0 AND usd_used = 0",
                         name: "chk_studio_ai_receipt_never_bill"
    add_check_constraint :studio_ai_execution_receipts,
                         %q(request_fingerprint ~ '^[0-9a-f]{64}$'),
                         name: "chk_studio_ai_receipt_fingerprint"
  end
end
