class AllowRequirementSetReviewVersions < ActiveRecord::Migration[8.1]
  def change
    # A source scope revision may produce multiple immutable owner review versions.
    # Keep the index for lookup, but only (intake, version) remains unique.
    remove_index :intake_requirement_sets, name: "idx_intake_requirement_sets_source"
    add_index :intake_requirement_sets, [:project_intake_id, :intake_scope_revision_id],
      name: "idx_intake_requirement_sets_source"
  end
end
