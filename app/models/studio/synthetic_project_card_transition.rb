module Studio
  # Append-only audit of fictional card state transitions, not project approval.
  class SyntheticProjectCardTransition < ApplicationRecord
    self.table_name = "studio_synthetic_project_card_transitions"
    belongs_to :synthetic_project_card, class_name: "Studio::SyntheticProjectCard",
               foreign_key: :studio_synthetic_project_card_id
    belongs_to :actor_user, class_name: "User"

    validates :sequence, numericality: { only_integer: true, greater_than: 0 }
    validates :from_state, :to_state, inclusion: { in: SyntheticProjectCard::STATES }
    validates :recorded_at, presence: true
    validate :allowed_edge_and_scope
    before_update :deny_mutation
    before_destroy :deny_mutation

    private

    def allowed_edge_and_scope
      card = synthetic_project_card
      allowed = { "backlog" => %w[in_review], "in_review" => %w[backlog on_hold],
                  "on_hold" => %w[backlog in_review] }
      unless Rails.env.test? && !Rails.env.production? &&
             allowed.fetch(from_state, []).include?(to_state) &&
             card && card.workspace_id == workspace_id &&
             card.client_id == client_id && card.project_intake_id == project_intake_id &&
             card.created_by_id == actor_user_id && card.workspace.owner_access?(actor_user)
        errors.add(:base, "Only owner-scoped fictional transition receipts are permitted")
      end
    end

    def deny_mutation
      errors.add(:base, "Synthetic transition history is immutable")
      throw :abort
    end
  end
end
