# Local bootstrap only. No public registration or tenant access is granted here.
class CreateOwnerAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, limit: 254, null: false
      t.string :password_digest, null: false
      t.string :role, limit: 20, default: "owner", null: false
      t.timestamps
    end

    add_index :users, "lower(email)", unique: true, name: "idx_users_email_case_insensitive"
    # Additional owners/workspaces will use memberships; do not add a global
    # unique index on the owner role that would block future multi-tenancy.

    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, limit: 64, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :user_sessions, :token_digest, unique: true
    add_index :user_sessions, :expires_at
  end
end
