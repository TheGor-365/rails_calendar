# Owner-only, never exposed to clients. No automatic ingestion or provider calls.
# Retention is explicit and required; a product retention/deletion policy must
# be approved before controllers are permitted to store real owner prompts.
class OwnerAiConversation < ApplicationRecord
  class Closed < StandardError; end
  class RequestConflict < StandardError; end

  belongs_to :workspace
  has_many :owner_ai_messages, inverse_of: :owner_ai_conversation, dependent: :restrict_with_exception

  validates :title, presence: true, length: { maximum: 100 }
  validates :state, inclusion: { in: %w[active archived] }
  validates :scope, inclusion: { in: %w[owner_general] }
  validates :retention_expires_at, presence: true
  validate :future_retention_on_creation, on: :create
  validate :workspace_owner_role

  before_validation :normalize_title
  before_destroy :prevent_deletion

  # Only owner-written draft text can be appended in C2.1a. AI/provider and
  # client message submission remain deliberately unimplemented.
  def append_owner_message!(body:, request_id:)
    normalized_body = body.to_s.strip
    with_lock do
      raise Closed, "Conversation is closed" unless state == "active" && retention_expires_at.future?

      existing = owner_ai_messages.find_by(request_id: request_id)
      if existing
        return existing if existing.role == "owner" && existing.body == normalized_body
        raise RequestConflict, "Request ID already belongs to different content"
      end

      owner_ai_messages.create!(
        role: "owner", state: "draft", body: normalized_body,
        request_id: request_id, sequence: (owner_ai_messages.maximum(:sequence) || 0) + 1
      )
    end
  end

  def archive!
    with_lock { update!(state: "archived") unless state == "archived" }
  end

  private

  def normalize_title
    self.title = title.to_s.strip if title
  end

  def future_retention_on_creation
    return if retention_expires_at.blank?
    errors.add(:retention_expires_at, "must be in the future") unless retention_expires_at.future?
  end

  def workspace_owner_role
    errors.add(:workspace, "must belong to an owner") unless workspace&.owner_user&.role == "owner"
  end

  def prevent_deletion
    errors.add(:base, "Conversation removal requires an approved retention policy")
    throw :abort
  end
end
