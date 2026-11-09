class CreateIntakeQuizAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :intake_answers do |t|
      t.references :project_intake, null: false, foreign_key: true
      t.string :question_key, limit: 64, null: false
      t.jsonb :selected_options, default: [], null: false
      t.string :other_text, limit: 300
      t.boolean :unsure, default: false, null: false
      t.text :comment
      t.integer :revision, default: 0, null: false
      t.timestamps
    end
    add_index :intake_answers, [:project_intake_id, :question_key],
              unique: true, name: "idx_intake_answers_unique_question"

    create_table :intake_answer_revisions do |t|
      t.references :intake_answer, null: false, foreign_key: true
      t.integer :revision, null: false
      t.jsonb :snapshot, default: {}, null: false
      t.timestamps
    end
    add_index :intake_answer_revisions, [:intake_answer_id, :revision],
              unique: true, name: "idx_intake_answer_revisions_unique"
  end
end
