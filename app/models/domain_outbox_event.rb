# C2.3b: private transactionally-enqueued delivery record.
# The outbox holds identifiers only, not AI prompts, client answers or files.
# Source models and their immutable revisions remain authoritative.
class DomainOutboxEvent < ApplicationRecord
  belongs_to :workspace

  STATES = %w[pending delivered failed].freeze
  SOURCES = {
    "IntakeRequirementSet" => "requirements_saved",
    "OwnerAiMessage" => "ai_reply_saved",
    "ClientRequestInvitation" => %w[
      invitation_issued invitation_claimed invitation_submitted invitation_revoked
    ].freeze,
    "ServiceOfferingPublication" => %w[service_published service_unpublished].freeze
  }.freeze
  MAX_ATTEMPTS = 5

  validates :source_type, inclusion: { in: SOURCES.keys }
  validates :kind, presence: true
  validates :state, inclusion: { in: STATES }
  validates :source_id, :source_version,
    numericality: { only_integer: true, greater_than: 0 }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :occurred_at, presence: true
  validates :source_version, uniqueness: {
    scope: %i[workspace_id source_type source_id kind]
  }
  validate :allowed_kind

  scope :due, ->(now = Time.current) {
    where(state: %w[pending failed]).where("attempts < ?", MAX_ATTEMPTS)
      .where("next_attempt_at IS NULL OR next_attempt_at <= ?", now)
      .order(:id)
  }

  # Called synchronously by IntakeRequirementSet#after_create, inside the
  # same DB transaction as that immutable revision. No external delivery.
  def self.enqueue_requirement_revision!(revision)
    workspace_id = revision.project_intake&.workspace_id
    return unless workspace_id.present? && revision.persisted?

    now = Time.current
    insert_all([{
      workspace_id: workspace_id,
      source_type: "IntakeRequirementSet", source_id: revision.id,
      source_version: revision.version, kind: "requirements_saved",
      occurred_at: revision.created_at, state: "pending", attempts: 0,
      created_at: now, updated_at: now
    }], unique_by: :idx_domain_outbox_source_revision)
  end

  # Enqueue only an actual persisted, settled assistant reply in the same
  # transaction as the status transition. Never queue a pending or uncertain
  # provider attempt. No answer body or client information is copied.
  def self.enqueue_settled_reply!(message)
    return unless message.persisted? && message.role == "assistant" &&
      message.state == "settled" && message.ai_spend_entry&.status == "settled"
    workspace_id = message.owner_ai_conversation&.workspace_id
    return unless workspace_id.present? &&
      message.ai_spend_entry.professional_profile&.workspace_id == workspace_id

    now = Time.current
    insert_all([{
      workspace_id: workspace_id, source_type: "OwnerAiMessage",
      source_id: message.id, source_version: message.sequence,
      kind: "ai_reply_saved", occurred_at: message.updated_at || now,
      state: "pending", attempts: 0, created_at: now, updated_at: now
    }], unique_by: :idx_domain_outbox_source_revision)
  end

  # Reuse each existing invitation transition as an immutable source event.
  # No token_digest, client answers, invitation URLs or free-text data are queued.
  INVITATION_EVENT_FIELDS = {
    "invitation_issued" => [1, :created_at],
    "invitation_claimed" => [2, :claimed_at],
    "invitation_submitted" => [3, :submitted_at],
    "invitation_revoked" => [4, :revoked_at]
  }.freeze

  def self.enqueue_invitation_transition!(invitation, kind:)
    mapping = INVITATION_EVENT_FIELDS[kind]
    return unless mapping && invitation.persisted? &&
      invitation.workspace_id.present?

    version, timestamp_field = mapping
    occurred_at = invitation.public_send(timestamp_field)
    return unless occurred_at.present?

    now = Time.current
    insert_all([{
      workspace_id: invitation.workspace_id, source_type: "ClientRequestInvitation",
      source_id: invitation.id, source_version: version, kind: kind,
      occurred_at: occurred_at, state: "pending", attempts: 0,
      created_at: now, updated_at: now
    }], unique_by: :idx_domain_outbox_source_revision)
  end

  # Immutable publication audits, not an approval action or a mutable
  # published_version_id pointer, are authoritative for this event.
  # Each audit source is its own v1 immutable event, including unpublish.
  def self.enqueue_service_publication!(publication)
    return unless publication.persisted?
    offering = publication.service_offering
    return unless offering&.workspace_id.present? &&
      publication.owner_user_id == offering.workspace.owner_user_id
    kind = case publication.event
    when "publish"
      return unless publication.service_offering_version&.approved? &&
        publication.service_offering_version.service_offering_id == offering.id
      "service_published"
    when "unpublish"
      return if publication.service_offering_version_id.present?
      "service_unpublished"
    end
    return unless kind

    now = Time.current
    insert_all([{
      workspace_id: offering.workspace_id,
      source_type: "ServiceOfferingPublication", source_id: publication.id,
      source_version: 1, kind: kind, occurred_at: publication.created_at,
      state: "pending", attempts: 0, created_at: now, updated_at: now
    }], unique_by: :idx_domain_outbox_source_revision)
  end

  private

  def allowed_kind
    errors.add(:kind, "is unsupported") unless Array(SOURCES[source_type]).include?(kind)
  end
end
