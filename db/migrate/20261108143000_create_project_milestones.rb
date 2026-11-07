# Independent project timeline: never modifies the shared consultation calendar.
class CreateProjectMilestones < ActiveRecord::Migration[8.1]
  def change
    create_table :project_milestones do |t|
      t.references :project_intake, null: false, foreign_key: true
      t.references :intake_spec_version, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :title, null: false, limit: 100
      t.text :description, null: false
      t.integer :suggested_work_days, null: false
      t.date :start_on, null: false
      t.date :end_on, null: false
      t.string :status, null: false, limit: 24, default: "proposed"
      t.timestamps
    end
    add_index :project_milestones, [:project_intake_id, :position],
              unique: true, name: "idx_project_milestone_position"
  end
end
