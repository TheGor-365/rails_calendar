module Studio
  # Immutable audit receipt of an owner's assertion, not proof of physical
  # recovery and never permission to replay the abandoned operation.
  class OperatorReview < ApplicationRecord
    self.table_name = "studio_operator_reviews"
    belongs_to :workspace
    belongs_to :maintenance_run, class_name: "Studio::MaintenanceRun",
               foreign_key: :studio_maintenance_run_id
    belongs_to :reviewed_by, class_name: "User"

    REASONS = %w[
      health_inspected inventory_inspected scan_tasks_inspected
      retention_objects_inspected
    ].freeze
    validates :reason_code, inclusion: { in: REASONS }
    validates :studio_maintenance_run_id, uniqueness: true
    validates :reviewed_at, presence: true
    validate :matching_workspace

    before_update :block_changes
    before_destroy :block_changes

    private

    def matching_workspace
      return unless maintenance_run
      errors.add(:workspace, "must match maintenance run") if workspace_id != maintenance_run.workspace_id
    end

    def block_changes
      errors.add(:base, "Operator review receipts are immutable")
      throw :abort
    end
  end
end
