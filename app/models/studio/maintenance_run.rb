module Studio
  # Persistent local audit record: one run per workspace, operation and slot.
  # No filenames, raw keys, error strings, tokens, or customer data.
  class MaintenanceRun < ApplicationRecord
    self.table_name = "studio_maintenance_runs"
    belongs_to :workspace

    KINDS = %w[health scan retention inventory].freeze
    STATES = %w[running succeeded failed].freeze
    validates :kind, inclusion: { in: KINDS }
    validates :state, inclusion: { in: STATES }
    validates :slot, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :summary_is_object
    validates :error_code, inclusion: { in: ["operation_failed"] }, allow_nil: true
    validates :finished_at, absence: true, if: -> { state == "running" }
    validates :finished_at, presence: true, if: -> { state != "running" }

    before_update :guard_transition
    before_destroy :prevent_destroy

    private

    def summary_is_object
      errors.add(:result_summary, "must be a JSON object") unless result_summary.is_a?(Hash)
    end

    def guard_transition
      changed = changes_to_save.keys - ["updated_at"]
      allowed = %w[state finished_at error_code result_summary]
      if state_in_database != "running" || !%w[succeeded failed].include?(state) ||
         (changed - allowed).any? || !changed.include?("state")
        errors.add(:base, "Maintenance run is append-only after termination")
        throw :abort
      end
    end

    def prevent_destroy
      errors.add(:base, "Maintenance audit run must be retained")
      throw :abort
    end
  end
end
