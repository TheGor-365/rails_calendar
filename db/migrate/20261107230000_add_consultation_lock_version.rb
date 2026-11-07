# Additive optimistic locking; retained consultations are not rescheduled.
class AddConsultationLockVersion < ActiveRecord::Migration[8.1]
  def change
    add_column :consultations, :lock_version, :integer, default: 0, null: false
  end
end
