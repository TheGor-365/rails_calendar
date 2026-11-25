class AddPublishedServiceSelectionsToIntakes < ActiveRecord::Migration[8.1]
  # Link customer-origin local intake to the exact immutable published offering
  # versions; an empty selection remains valid for a free-form request.
  def change
    add_reference :project_intakes, :workspace, null: true, foreign_key: true

    create_table :intake_service_selections do |t|
      t.references :project_intake, null: false, foreign_key: true
      t.references :service_offering_version, null: false, foreign_key: true,
                   index: { name: "index_intake_service_selections_on_version_id" }
      t.timestamps
    end
    add_index :intake_service_selections,
              %i[project_intake_id service_offering_version_id],
              unique: true, name: "idx_intake_service_selection_unique"
  end
end
