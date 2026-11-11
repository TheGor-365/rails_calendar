module Studio
  # Preferences only; neither consent nor a model choice can enable egress.
  class AiPolicy < ApplicationRecord
    self.table_name = "studio_ai_policies"
    MODES = %w[off offline reviewed_provider].freeze
    PURPOSES = %w[clarify source_outline document_proposal].freeze

    belongs_to :workspace
    belongs_to :project_intake, optional: true

    validates :mode, inclusion: { in: MODES }
    validates :token_cap_per_call, :token_cap_per_day,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :usd_cap_per_call, :usd_cap_per_month,
              numericality: { greater_than_or_equal_to: 0 }
    validate :allowed_purposes_only
    validate :scoped_project

    private

    def allowed_purposes_only
      unless purposes.is_a?(Array) && purposes.uniq == purposes &&
             purposes.all? { |value| PURPOSES.include?(value) }
        errors.add(:purposes, "must be a unique set of registered purposes")
      end
    end

    def scoped_project
      return unless project_intake
      unless project_intake.persisted? && project_intake.workspace_id == workspace_id
        errors.add(:project_intake, "must belong to the same workspace")
      end
    end
  end
end
