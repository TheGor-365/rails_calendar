class CreateClientEmailSignups < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_verified_at, :datetime
    add_column :users, :signup_consent_at, :datetime
    add_column :users, :signup_policy_version, :string, limit: 80
    create_table :client_signup_challenges do |t|
      t.string :email, limit: 254, null: false
      t.string :password_digest, null: false
      t.string :code_digest, limit: 64, null: false
      t.datetime :expires_at, null: false
      t.datetime :sent_at, null: false
      t.datetime :consent_at, null: false
      t.string :policy_version, limit: 80, null: false
      t.integer :failed_attempts, default: 0, null: false
      t.integer :send_count, default: 1, null: false
      t.datetime :window_started_at, null: false
      t.timestamps
    end
    add_index :client_signup_challenges, "lower(email)", unique: true, name: "idx_client_signup_email_unique"
    add_index :client_signup_challenges, :expires_at
    create_table :signup_rate_windows do |t|
      t.string :identity_digest, limit: 64, null: false
      t.string :purpose, limit: 32, null: false
      t.bigint :window_start_epoch, null: false
      t.integer :attempts, default: 0, null: false
      t.timestamps
    end
    add_index :signup_rate_windows, %i[purpose identity_digest window_start_epoch], unique: true, name: "idx_signup_rate_window_unique"
    add_index :signup_rate_windows, :window_start_epoch
  end
end
