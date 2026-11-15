class CreateOwnerIntakeReadStates < ActiveRecord::Migration[8.1]
  def change
    create_table :owner_intake_read_states do |t|
      t.references :owner_user, null: false, index: false, foreign_key: { to_table: :users }
      t.references :project_intake, null: false, index: false, foreign_key: true
      t.references :last_seen_client_message, null: false, index: false, foreign_key: { to_table: :intake_messages }
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end

    add_index :owner_intake_read_states, %i[owner_user_id project_intake_id],
              unique: true, name: "idx_owner_intake_read_state_unique"
    add_index :owner_intake_read_states, :project_intake_id,
              name: "idx_owner_intake_read_state_intake"
  end
end
