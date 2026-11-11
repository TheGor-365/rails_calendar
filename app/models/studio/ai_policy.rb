module Studio
  # Configured policy != permission to call a model. External providers are
  # intentionally NOT implemented; system hard-deny always wins.
  class AiPolicy < ApplicationRecord
    self.table_name = "studio_ai_policies"
    belongs_to :workspace
    belongs_to :project_intake, optional: true

    MODES = %w[off offline reviewed_provider].freeze
    PURPOSES = %w[document_plan].freeze
    DATA_CLASSES = %w[synthetic].freeze
    TOKEN_CAPS = %w[per_call_token_cap project_token_cap daily_token_cap monthly_token_cap].freeze
    USD_CAPS = %w[per_call_usd_cap project_usd_cap daily_usd_cap monthly_usd_cap].freeze

    validates :mode, inclusion: { in: MODES }
    TOKEN_CAPS.each { |name| validates name, numericality: { only_integer: true, greater_than_or_equal_to: 0 } }
    USD_CAPS.each { |name| validates name, numericality: { greater_than_or_equal_to: 0 } }
    validate :strict_allowlists
    validate :intake_matches_workspace

    private

    def strict_allowlists
      { allowed_purposes: PURPOSES, allowed_data_classes: DATA_CLASSES }.each do |field, valid|
        values = public_send(field)
        unless values.is_a?(Array) && values.all? { |value| value.is_a?(String) && valid.include?(value) } &&
               values.uniq.size == values.size
          errors.add(field, "must contain only unique supported values")
        end
      end
    end

    def intake_matches_workspace
      return if project_intake_id.nil?

      if project_intake.nil? || project_intake.workspace_id != workspace_id ||
         project_intake.client_id.nil?
        errors.add(:project_intake, "must be an assigned intake in this workspace")
      end
    end
  end
end
