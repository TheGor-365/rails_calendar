class AddClientOwnershipToProjectIntakes < ActiveRecord::Migration[8.1]
  def change
    # Legacy synthetic intakes remain unassigned; no automatic reassignment.
    add_reference :project_intakes, :client_user, null: true,
                  foreign_key: {to_table: :users}, index: true
  end
end
