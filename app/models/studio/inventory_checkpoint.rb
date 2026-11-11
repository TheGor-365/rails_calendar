module Studio
  # Synthetic pagination state. Provider continuation token is encrypted and
  # summary contains ONLY bounded allowlisted counters (no keys or filenames).
  class InventoryCheckpoint < ApplicationRecord
    self.table_name = "studio_inventory_checkpoints"
    belongs_to :workspace

    STATES = %w[listing checking completed failed].freeze
    COUNTERS = %w[
      listed owned_by_workspace foreign_workspace orphan_candidates_review_only
      recent_unreferenced unknown_timestamp invalid_keys db_heads_checked
      db_missing_objects db_head_errors
    ].freeze

    validates :state, inclusion: { in: STATES }
    validates :config_digest, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :pages_scanned, numericality: { only_integer: true, in: 0..10_000 }
    validates :last_db_blob_id, :db_target_max_id,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :expires_at, presence: true
    validate :safe_state

    before_update :guard_terminal
    before_destroy :retain_history

    def finished?
      %w[completed failed].include?(state)
    end

    private

    def safe_state
      unless counts.is_a?(Hash) &&
             counts.keys.all? { |k| COUNTERS.include?(k.to_s) } &&
             counts.values.all? { |v| v.is_a?(Integer) && v >= 0 }
        errors.add(:counts, "must contain allowlisted nonnegative counts")
      end
      unless seen_cursor_digests.is_a?(Array) &&
             seen_cursor_digests.length <= 10_000 &&
             seen_cursor_digests.all? { |d| d.is_a?(String) && d.match?(/\A[0-9a-f]{64}\z/) }
        errors.add(:seen_cursor_digests, "must be hashed cursors")
      end
      errors.add(:finished_at, "must match terminal state") if finished? != finished_at.present?
    end

    def guard_terminal
      if %w[completed failed].include?(state_in_database)
        errors.add(:base, "Checkpoint is terminal and immutable")
        throw :abort
      end
      allowed = %w[state encrypted_cursor seen_cursor_digests counts
                   pages_scanned last_db_blob_id finished_at error_code updated_at]
      if (changes_to_save.keys - allowed).any? ||
         pages_scanned < pages_scanned_in_database ||
         last_db_blob_id < last_db_blob_id_in_database
        errors.add(:base, "Checkpoint cannot roll back or change identity")
        throw :abort
      end
    end

    def retain_history
      errors.add(:base, "Checkpoint history must be retained")
      throw :abort
    end
  end
end
