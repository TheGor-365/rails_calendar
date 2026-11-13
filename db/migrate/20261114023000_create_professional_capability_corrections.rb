class CreateProfessionalCapabilityCorrections < ActiveRecord::Migration[8.1]
  def change
    create_table :professional_capability_corrections do |t|
      t.references :professional_profile, null: false, foreign_key: true,
                                      index: { name: "idx_cap_correction_profile" }
      t.string :domain, limit: 80, null: false
      t.integer :base_snapshot_version, null: false
      t.string :delivery_mode, limit: 20, null: false
      t.string :experience_claim, limit: 20, null: false
      t.string :willingness, limit: 24, null: false
      t.text :conditions
      t.timestamps
    end
    add_index :professional_capability_corrections,
              [:professional_profile_id, :domain], unique: true,
              name: "idx_cap_correction_unique_domain"
    add_check_constraint :professional_capability_corrections,
                         "base_snapshot_version > 0", name: "chk_cap_correction_version"
    add_check_constraint :professional_capability_corrections,
                         "char_length(conditions) <= 600", name: "chk_cap_correction_conditions"
  end
end
