class CreateIntakeScopeRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :intake_scope_revisions do |t|
      t.references :project_intake, null: false, foreign_key: true
      t.integer :version, null: false
      t.string :author_role, null: false, limit: 16
      t.jsonb :answers, null: false, default: {}
      t.timestamps
    end
    add_index :intake_scope_revisions, [:project_intake_id, :version],
      unique: true, name: "idx_intake_scope_revisions_version"
    add_check_constraint :intake_scope_revisions, "version > 0",
      name: "chk_intake_scope_version_positive"
    add_check_constraint :intake_scope_revisions, "author_role IN ('owner', 'client')",
      name: "chk_intake_scope_author_role"
  end
end
