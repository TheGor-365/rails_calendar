module Studio
  # Database-backed, bounded synthetic scan queue. No user-supplied error text
  # or raw file content is persisted here.
  class SourceScanTask < ApplicationRecord
    self.table_name = "studio_source_scan_tasks"

    belongs_to :workspace
    belongs_to :project_source_blob

    PENDING = %w[queued retry_wait].freeze
    TERMINAL = %w[complete_clean complete_infected exhausted expired cancelled].freeze
    STATES = (PENDING + TERMINAL).freeze
    MAX_ATTEMPTS = 3

    validates :state, inclusion: { in: STATES }
    validates :attempts, numericality: { only_integer: true, in: 0..MAX_ATTEMPTS }
    validates :project_source_blob_id, uniqueness: true
    validates :next_attempt_at, presence: true
    validates :last_error_code, inclusion: { in: ["scan_denied"] }, allow_nil: true
    validate :matching_tenant
    validate :finished_timestamp_consistency

    before_update :guard_update
    before_destroy :prevent_destroy

    scope :due, ->(now = Time.current) {
      where(state: PENDING).where("next_attempt_at <= ?", now)
    }

    private

    def matching_tenant
      return unless project_source_blob
      errors.add(:workspace, "must match blob") unless workspace_id == project_source_blob.workspace_id
    end

    def finished_timestamp_consistency
      if TERMINAL.include?(state) != finished_at.present?
        errors.add(:finished_at, "must match terminal state")
      end
    end

    def guard_update
      allowed = %w[state attempts next_attempt_at last_error_code finished_at updated_at]
      changed = changes_to_save.keys
      if (changed - allowed).any? || TERMINAL.include?(state_in_database) ||
         attempts < attempts_in_database
        errors.add(:base, "Scan task identity and terminal state are immutable")
        throw :abort
      end
    end

    def prevent_destroy
      errors.add(:base, "Scan tasks are retained for audit")
      throw :abort
    end
  end
end
