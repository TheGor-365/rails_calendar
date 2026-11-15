class AddClientSubmissionKeyToIntakeMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :intake_messages, :client_submission_key, :string, limit: 32
    add_index :intake_messages, %i[project_intake_id client_submission_key],
              unique: true, where: "client_submission_key IS NOT NULL",
              name: "idx_intake_messages_client_submission_unique"
  end
end
