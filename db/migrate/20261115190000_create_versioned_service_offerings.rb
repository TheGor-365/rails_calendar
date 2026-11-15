class CreateVersionedServiceOfferings < ActiveRecord::Migration[8.1]
  def change
    create_table :service_offerings do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :key, limit: 32, null: false
      t.integer :position, null: false, default: 0
      t.bigint :approved_version_id
      t.bigint :published_version_id
      t.timestamps
    end
    add_index :service_offerings, %i[workspace_id key], unique: true,
              name: "idx_service_offerings_workspace_key"
    add_index :service_offerings, :approved_version_id
    add_index :service_offerings, :published_version_id

    create_table :service_offering_versions do |t|
      t.references :service_offering, null: false, foreign_key: true
      t.references :professional_context_snapshot, null: false, foreign_key: true,
                     index: { name: "idx_offering_version_snapshot" }
      t.references :professional_capability, null: false, foreign_key: true,
                     index: { name: "idx_offering_version_capability" }
      t.integer :version, null: false
      t.string :title, limit: 120, null: false
      t.text :summary, null: false
      t.text :included_scope, null: false
      t.text :excluded_scope, null: false
      t.text :requirements_prompt
      t.string :project_category, limit: 32, null: false
      t.string :delivery_mode, limit: 20, null: false
      t.string :source_capability_domain, limit: 80, null: false
      t.string :digest, limit: 64, null: false
      t.datetime :approved_at
      t.timestamps
    end
    add_index :service_offering_versions, %i[service_offering_id version],
              unique: true, name: "idx_service_offering_versions_unique"
    add_index :service_offering_versions, :service_offering_id, unique: true,
              where: "approved_at IS NULL", name: "idx_service_offering_single_draft"
    add_check_constraint :service_offering_versions, "version > 0",
                         name: "chk_service_offering_version_positive"
    add_check_constraint :service_offering_versions,
                         "delivery_mode IN ('direct', 'conditional', 'evaluate_first')",
                         name: "chk_service_offering_delivery_mode"

    add_foreign_key :service_offerings, :service_offering_versions,
                    column: :approved_version_id
    add_foreign_key :service_offerings, :service_offering_versions,
                    column: :published_version_id

    create_table :service_offering_publications do |t|
      t.references :service_offering, null: false, foreign_key: true,
                    index: { name: "idx_service_publication_offering" }
      t.references :service_offering_version, null: true, foreign_key: true,
                    index: { name: "idx_service_publication_version" }
      t.references :owner_user, null: false, foreign_key: { to_table: :users },
                    index: { name: "idx_service_publication_owner" }
      t.string :event, null: false, limit: 16
      t.timestamps
    end
    add_check_constraint :service_offering_publications,
                         "event IN ('publish', 'unpublish')",
                         name: "chk_service_publication_event"
  end
end
