class CreateActivityEventReads < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_event_reads do |t|
      t.references :activity_event, null: false, foreign_key: true
      t.references :owner_user, null: false, foreign_key: { to_table: :users }
      t.datetime :read_at, null: false
    end
    add_index :activity_event_reads, [:owner_user_id, :activity_event_id],
      unique: true, name: "idx_activity_event_reads_owner_event"
    add_index :activity_event_reads, [:owner_user_id, :read_at],
      name: "idx_activity_event_reads_owner_time"
  end
end
