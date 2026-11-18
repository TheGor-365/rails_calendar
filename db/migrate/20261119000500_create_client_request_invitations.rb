class CreateClientRequestInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :client_request_invitations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :token_digest, limit: 64, null: false
      t.string :seed_title, limit: 120, null: false
      t.string :seed_project_type, limit: 32, null: false
      t.text :seed_goal, null: false
      t.jsonb :service_version_ids, null: false, default: []
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :claimed_at
      t.references :claimed_by_user, foreign_key: { to_table: :users }
      t.references :project_intake, foreign_key: true
      t.datetime :submitted_at
      t.timestamps
    end

    add_index :client_request_invitations, :token_digest, unique: true
    add_index :client_request_invitations, :project_intake_id, unique: true
    add_index :client_request_invitations, [:workspace_id, :created_at]
    add_check_constraint :client_request_invitations,
      "char_length(token_digest) = 64", name: "chk_client_invite_digest_length"
    add_check_constraint :client_request_invitations,
      "(claimed_at IS NULL AND claimed_by_user_id IS NULL AND project_intake_id IS NULL) OR " \
      "(claimed_at IS NOT NULL AND claimed_by_user_id IS NOT NULL AND project_intake_id IS NOT NULL)",
      name: "chk_client_invite_claim_triplet"
  end
end
