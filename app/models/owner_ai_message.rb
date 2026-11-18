require "securerandom"

# Private, bounded transcript record. Does not invoke AI or change any product data.
# The cost ledger is a separate, append-only source of truth for paid requests.
class OwnerAiMessage < ApplicationRecord
  belongs_to :owner_ai_conversation, inverse_of: :owner_ai_messages
  belongs_to :parent_message, class_name: "OwnerAiMessage", optional: true
  belongs_to :ai_spend_entry, optional: true
  # Existing Active Storage tables: no schema change or public signed file routes.
  has_many_attached :files

  ROLES = %w[owner assistant].freeze
  STATES = %w[draft pending settled failed uncertain].freeze

  validates :role, inclusion: { in: ROLES }
  validates :state, inclusion: { in: STATES }
  validates :sequence, numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: :owner_ai_conversation_id }
  validates :request_id, presence: true, uniqueness: { scope: :owner_ai_conversation_id }
  validates :body, presence: true
  validates :body, length: { maximum: 1200 }, if: :owner_message?
  validates :body, length: { maximum: 2800 }, if: :assistant_message?
  validates :approved_profile_version, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :conversation_active_on_creation, on: :create
  validate :parent_in_same_conversation
  validate :settled_assistant_has_ledger
  validate :ledger_belongs_to_conversation_owner
  validate :operation_is_allowed

  before_validation :set_request_id, on: :create

  scope :in_order, -> { order(:sequence, :id) }

  def owner_message?
    role == "owner"
  end

  def assistant_message?
    role == "assistant"
  end

  private

  def set_request_id
    self.request_id ||= SecureRandom.uuid
  end

  def conversation_active_on_creation
    return unless owner_ai_conversation
    errors.add(:owner_ai_conversation, "is archived") if owner_ai_conversation.archived?
  end

  def parent_in_same_conversation
    return unless parent_message
    if parent_message.id == id && id.present?
      errors.add(:parent_message, "cannot reference itself")
    elsif parent_message.owner_ai_conversation_id != owner_ai_conversation_id ||
          parent_message.id.blank?
      errors.add(:parent_message, "must be saved in the same conversation")
    end
  end

  def settled_assistant_has_ledger
    return unless assistant_message? && state == "settled"
    errors.add(:ai_spend_entry, "is required for a settled assistant message") unless ai_spend_entry
  end

  def ledger_belongs_to_conversation_owner
    return unless ai_spend_entry && owner_ai_conversation
    profile = owner_ai_conversation.workspace&.professional_profile
    unless profile && ai_spend_entry.professional_profile_id == profile.id &&
           ai_spend_entry.project_intake_id.nil? &&
           [OwnerAi::Composer::VERSION, OwnerAi::ConversationResponder::VERSION].include?(ai_spend_entry.operation)
      errors.add(:ai_spend_entry, "must belong to this owner's AI composer")
    end
  end

  def operation_is_allowed
    return if operation.blank?
    errors.add(:operation, "is not supported") unless OwnerAi::OperationRegistry.fetch(operation)
  end
end
