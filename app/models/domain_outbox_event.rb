# C2.3b: private transactionally-enqueued delivery record.
# The outbox holds identifiers only, not AI prompts, client answers or files.
# Source models and their immutable revisions remain authoritative.
class DomainOutboxEvent < ApplicationRecord
  belongs_to :workspace

  STATES = %w[pending delivered failed].freeze
  SOURCES = { "IntakeRequirementSet" => "requirements_saved" }.freeze
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

  private

  def allowed_kind
    errors.add(:kind, "is unsupported") if SOURCES[source_type] != kind
  end
end
