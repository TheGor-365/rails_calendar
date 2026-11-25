class CreateActivityEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_events do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :event_key, null: false, limit: 180
      t.string :kind, null: false, limit: 48
      t.string :subject_type, null: false, limit: 60
      t.bigint :subject_id, null: false
      t.string :title, null: false, limit: 180
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :activity_events, [:workspace_id, :event_key], unique: true,
      name: "idx_activity_events_workspace_key"
    add_index :activity_events, [:workspace_id, :occurred_at, :id],
      name: "idx_activity_events_workspace_time"
    add_index :activity_events, [:workspace_id, :subject_type, :subject_id],
      name: "idx_activity_events_workspace_subject"
    add_check_constraint :activity_events, "length(event_key) > 0 AND length(kind) > 0",
      name: "chk_activity_events_names"
    add_check_constraint :activity_events, "subject_id > 0",
      name: "chk_activity_events_subject"
  end
end
