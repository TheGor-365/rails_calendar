# A durable, private queue committed together with the canonical source record.
# No existing rows, schemas or deployed databases are modified by this file alone.
class CreateDomainOutboxEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :domain_outbox_events do |t|
      t.references :workspace, null: false, foreign_key: true, index: true
      t.string :source_type, null: false, limit: 48
      t.bigint :source_id, null: false
      t.integer :source_version, null: false
      t.string :kind, null: false, limit: 48
      t.string :state, null: false, limit: 16, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.datetime :occurred_at, null: false
      t.datetime :next_attempt_at
      t.datetime :delivered_at
      t.string :last_error_code, limit: 80
      t.timestamps
    end

    add_index :domain_outbox_events,
      %i[workspace_id source_type source_id source_version kind],
      unique: true, name: "idx_domain_outbox_source_revision"
    add_index :domain_outbox_events,
      %i[state next_attempt_at id],
      name: "idx_domain_outbox_delivery_queue"

    add_check_constraint :domain_outbox_events, "source_id > 0 AND source_version > 0",
      name: "chk_domain_outbox_source_positive"
    add_check_constraint :domain_outbox_events, "attempts >= 0",
      name: "chk_domain_outbox_attempts_nonnegative"
    add_check_constraint :domain_outbox_events,
      "state IN ('pending', 'delivered', 'failed')",
      name: "chk_domain_outbox_valid_state"
  end
end
