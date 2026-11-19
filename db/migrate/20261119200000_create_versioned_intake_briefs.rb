# E2.1 local pilot: invitation owner inputs remain immutable; a claimed
# intake receives separate role-attributed revisions for client clarification.
class CreateVersionedIntakeBriefs < ActiveRecord::Migration[8.1]
  def change
    add_column :client_request_invitations, :brief_selections, :jsonb, null: false, default: {}
    add_column :client_request_invitations, :brief_decisions, :jsonb, null: false, default: {}
    add_column :client_request_invitations, :brief_notes, :string, limit: 350

    create_table :intake_brief_revisions do |t|
      t.references :project_intake, null: false, foreign_key: true
      t.integer :version, null: false
      t.string :author_role, null: false, limit: 12
      t.jsonb :selections, null: false, default: {}
      t.jsonb :decisions, null: false, default: {}
      t.string :notes, limit: 350
      t.timestamps
    end
    add_index :intake_brief_revisions, [:project_intake_id, :version],
      unique: true, name: "idx_intake_brief_revisions_version"
    add_check_constraint :intake_brief_revisions, "version > 0",
      name: "chk_intake_brief_version_positive"
    add_check_constraint :intake_brief_revisions, "author_role IN ('owner', 'client')",
      name: "chk_intake_brief_author_role"
  end
end
