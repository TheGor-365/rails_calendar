# Immutable owner-workspace event index, not a replacement for authoritative models.
# Do not store invitation tokens, private client answers, prompts or credentials.
class ActivityEvent < ApplicationRecord
  belongs_to :workspace
  has_many :activity_event_reads, dependent: :restrict_with_exception

  KINDS = %w[invitation_issued invitation_claimed invitation_submitted invitation_revoked
             intake_created requirements_saved ai_attempted ai_settled ai_uncertain
             ai_cancelled conversation_created].freeze
  SUBJECT_TYPES = %w[ClientRequestInvitation ProjectIntake IntakeRequirementSet
                     AiSpendEntry OwnerAiConversation].freeze

  validates :event_key, presence: true, length: { maximum: 180 },
    uniqueness: { scope: :workspace_id }
  validates :kind, inclusion: { in: KINDS }
  validates :subject_type, inclusion: { in: SUBJECT_TYPES }
  validates :subject_id, numericality: { only_integer: true, greater_than: 0 }
  validates :title, presence: true, length: { maximum: 180 }
  validates :occurred_at, presence: true
  validate :safe_metadata

  def readonly?
    persisted?
  end

  def destroy
    raise ActiveRecord::ReadOnlyError, "Activity history is immutable"
  end

  private

  def safe_metadata
    return if metadata.is_a?(Hash) && metadata.keys.sort == %w[operation status version].intersection(metadata.keys).sort &&
      metadata.to_json.bytesize <= 512
    errors.add(:metadata, "contains unsupported fields")
  end
end
