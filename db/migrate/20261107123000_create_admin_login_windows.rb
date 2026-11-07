# Shared, atomic, fixed-window limiter for administrator login attempts.
# Additive migration: it never alters or removes consultation records.
class CreateAdminLoginWindows < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_login_windows do |t|
      t.string :client_digest, null: false, limit: 64
      t.bigint :window_start_epoch, null: false
      t.integer :attempts, null: false, default: 0
      t.timestamps
    end

    add_index :admin_login_windows, [:client_digest, :window_start_epoch],
              unique: true, name: "idx_admin_login_windows_identity_and_window"
    add_index :admin_login_windows, :window_start_epoch,
              name: "idx_admin_login_windows_cleanup"
  end
end
