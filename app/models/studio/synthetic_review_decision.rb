module Studio
  # Append-only owner triage receipt for fictional source comparisons. No
  # document or client approval, no persisted source text, no AI.
  class SyntheticReviewDecision < ApplicationRecord
    self.table_name = "studio_synthetic_review_decisions"
    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake
    belongs_to :baseline_source, class_name: "ProjectSource"
    belongs_to :incoming_source, class_name: "ProjectSource"
    belongs_to :reviewed_by, class_name: "User"

    STATES = %w[new corroborates conflicts unknown].freeze
    RESOLUTIONS = %w[needs_information retain_for_review exclude_from_draft].freeze

    validates :candidate_state, inclusion: { in: STATES }
    validates :resolution, inclusion: { in: RESOLUTIONS }
    validates :comparison_digest, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :incoming_fact_id, format: { with: /\Afact-[0-9a-f]{24}\z/ }
    validates :reviewed_at, presence: true
    validate :consistent_scope
    validate :no_unresolved_accept

    before_update :immutable!
    before_destroy :immutable!

    private

    def consistent_scope
      unless client&.workspace_id == workspace_id &&
             project_intake&.workspace_id == workspace_id &&
             project_intake&.client_id == client_id &&
             [baseline_source, incoming_source].all? { |source|
               source&.workspace_id == workspace_id && source&.client_id == client_id &&
                 source&.project_intake_id == project_intake_id
             }
        errors.add(:base, "Synthetic review tenant mismatch")
      end
    end

    def no_unresolved_accept
      if !%w[new corroborates].include?(candidate_state) && resolution == "retain_for_review"
        errors.add(:resolution, "cannot retain an unresolved claim")
      end
    end

    def immutable!
      errors.add(:base, "Synthetic triage decision is append-only")
      throw :abort
    end
  end
end
