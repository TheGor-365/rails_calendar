class CreateIntakeRequirementSets < ActiveRecord::Migration[8.1]
  def change
    create_table :intake_requirement_sets do |t|
      t.references :project_intake, null: false, foreign_key: true
      t.references :intake_scope_revision, null: false, foreign_key: true
      t.integer :version, null: false
      t.jsonb :requirements, null: false, default: []
      t.timestamps
    end
    add_index :intake_requirement_sets, [:project_intake_id, :version],
      unique: true, name: "idx_intake_requirement_sets_version"
    add_index :intake_requirement_sets, [:project_intake_id, :intake_scope_revision_id],
      unique: true, name: "idx_intake_requirement_sets_source"
    add_check_constraint :intake_requirement_sets, "version > 0",
      name: "chk_intake_requirement_set_version"
  end
end
