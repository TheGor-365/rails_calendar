# Private owner transcript storage. Each message is append-only in C2.1a:
# future provider outcomes must use an explicit audited transition design.
class OwnerAiMessage < ApplicationRecord
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  belongs_to :owner_ai_conversation, inverse_of: :owner_ai_messages
  belongs_to :parent_message, class_name: "OwnerAiMessage", optional: true
  belongs_to :ai_spend_entry, optional: true

  validates :request_id, presence: true, format: { with: UUID_PATTERN },
                         uniqueness: { scope: :owner_ai_conversation_id }
  validates :sequence, numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: :owner_ai_conversation_id }
  validates :body, presence: true, length: { maximum: 2_800 }
  validates :role, inclusion: { in: %w[owner assistant] }
  validates :state, inclusion: { in: %w[draft pending settled failed uncertain] }
  validates :operation, length: { maximum: 40 }, allow_nil: true
  validates :approved_profile_version, numericality: { only_integer: true, greater_than: 0 },
                                       allow_nil: true
  validate :role_and_state_consistency
  validate :parent_belongs_to_same_conversation
  validate :ledger_matches_owner
  validate :registered_operation

  before_update :prevent_mutation
  before_destroy :prevent_removal

  private

  def role_and_state_consistency
    if role == "owner"
      errors.add(:state, "not valid for owner message") unless %w[draft settled].include?(state)
      errors.add(:ai_spend_entry, "not allowed for owner messages") if ai_spend_entry_id.present?
      errors.add(:body, "too long for owner input") if body.to_s.length > 1_200
    elsif role == "assistant"
      errors.add(:state, "not valid for assistant message") unless %w[pending settled failed uncertain].include?(state)
      errors.add(:ai_spend_entry, "required for settled assistant output") if state == "settled" && ai_spend_entry_id.blank?
    end
  end

  def parent_belongs_to_same_conversation
    return unless parent_message_id.present?
    errors.add(:parent_message, "must belong to this conversation") unless
      parent_message&.owner_ai_conversation_id == owner_ai_conversation_id
  end

  def ledger_matches_owner
    return unless ai_spend_entry_id.present?

    profile = owner_ai_conversation&.workspace&.professional_profile
    if ai_spend_entry&.professional_profile_id != profile&.id ||
       ai_spend_entry&.project_intake_id.present?
      errors.add(:ai_spend_entry, "must belong to this owner profile")
    elsif state == "settled" && ai_spend_entry.status != "settled"
      errors.add(:ai_spend_entry, "must be reconciled before settled output")
    end
  end

  def registered_operation
    return if operation.blank?
    errors.add(:operation, "not allowed") unless OwnerAi::OperationRegistry.fetch(operation)
  end

  def prevent_mutation
    errors.add(:base, "Messages are append-only")
    throw :abort
  end

  def prevent_removal
    errors.add(:base, "Message removal requires an approved retention policy")
    throw :abort
  end
end
