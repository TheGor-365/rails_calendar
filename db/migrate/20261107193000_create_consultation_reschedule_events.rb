class CreateConsultationRescheduleEvents < ActiveRecord::Migration[8.1]
  def change
    # The current application physically deletes consultations. Preserve audit
    # snapshots even after a later deletion; no FK/cascade until a retention
    # and soft-delete policy is approved. Access remains administrator-only.
    create_table :consultation_reschedule_events do |t|
      t.bigint :consultation_id, null: false
      t.datetime :old_start_time, null: false
      t.datetime :old_end_time, null: false
      t.datetime :new_start_time, null: false
      t.datetime :new_end_time, null: false
      t.string :actor_label, null: false, limit: 80
      t.text :reason, null: false
      t.datetime :created_at, null: false
    end

    add_index :consultation_reschedule_events,
              [:consultation_id, :created_at, :id],
              name: "idx_reschedule_history_by_consultation_and_time"
  end
end
