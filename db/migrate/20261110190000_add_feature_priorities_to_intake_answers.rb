class AddFeaturePrioritiesToIntakeAnswers < ActiveRecord::Migration[8.1]
  def change
    # Additive only: old answers default to "unprioritized" and remain intact.
    add_column :intake_answers, :feature_priorities, :jsonb, default: {}, null: false
  end
end
