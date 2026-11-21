# Append-only account-owned snapshots of the 12-part discovery questionnaire.
# These are *inputs* to a future specification, not an approved contract.
class IntakeScopeRevision < ApplicationRecord
  belongs_to :project_intake

  validates :version, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :project_intake_id }
  validates :author_role, inclusion: { in: %w[owner client] }
  validate :supported_answers

  # Persisted client/owner answers are not copied into the event envelope.
  # Creation and enqueue happen atomically; historical snapshots stay immutable.
  after_create :enqueue_scope_revision
  after_create_commit :record_scope_revision

  def enqueue_scope_revision
    DomainOutboxEvent.enqueue_scope_revision!(self)
  end

  def record_scope_revision
    return unless project_intake.workspace_id.present?
    Activity::Recorder.record!(
      workspace: project_intake.workspace, subject: self,
      kind: "scope_revision_saved",
      title: "#{author_role == 'client' ? 'Client' : 'Owner'} scope revision v#{version}",
      occurred_at: created_at, metadata: { "version" => version }
    )
  end

  def readonly?
    persisted?
  end

  private

  def supported_answers
    errors.add(:answers, "contains unsupported sections or statuses") unless IntakeScopeSections.normalize(answers)
  end
end
