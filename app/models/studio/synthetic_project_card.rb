module Studio
  # Synthetic metadata only. A card is not an approved requirement or a real
  # client task. No free-text title, body, source bytes or deadline is stored.
  class SyntheticProjectCard < ApplicationRecord
    self.table_name = "studio_synthetic_project_cards"
    STATES = %w[backlog in_review on_hold].freeze
    ARTIFACT_KEYS = Studio::DocumentGenerationPlan::DEFINITIONS.map { |x| x.fetch(:key) }.freeze

    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake
    belongs_to :created_by, class_name: "User"
    has_many :transitions, class_name: "Studio::SyntheticProjectCardTransition",
             foreign_key: :studio_synthetic_project_card_id,
             dependent: :restrict_with_exception

    attr_accessor :transition_actor

    validates :artifact_key, inclusion: { in: ARTIFACT_KEYS }
    validates :state, inclusion: { in: STATES }
    validates :lock_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :synthetic_owner_and_scope
    before_update :allow_only_authorized_state_transition
    before_destroy :deny_removal

    private

    def synthetic_owner_and_scope
      unless Rails.env.test? && !Rails.env.production? &&
             workspace&.owner_access?(created_by) &&
             client&.workspace_id == workspace_id &&
             project_intake&.workspace_id == workspace_id &&
             project_intake&.client_id == client_id
        errors.add(:base, "Only exact-scope fictional owner cards are permitted")
      end
    end

    def allow_only_authorized_state_transition
      unless transition_actor&.id == created_by_id &&
             workspace&.owner_access?(transition_actor) &&
             will_save_change_to_state? &&
             (changes_to_save.keys - %w[state lock_version updated_at]).empty?
        errors.add(:base, "Use owner-scoped synthetic transition service")
        throw :abort
      end
    end

    def deny_removal
      errors.add(:base, "Synthetic cards cannot be deleted")
      throw :abort
    end
  end
end
