# Durable, append-only accounting for a paid provider attempt. Never store API keys or raw prompts.
# 'uncertain' holds its reservation indefinitely when billing is ambiguous; no automatic retry.
class AiSpendEntry < ApplicationRecord
  belongs_to :project_intake, optional: true
  belongs_to :professional_profile, optional: true
  validate :exactly_one_subject
  validates :operation, presence: true, length: { maximum: 40 }
  validates :model, presence: true, length: { maximum: 64 }
  validates :request_digest, presence: true, length: { is: 64 }, uniqueness: true
  validates :status, inclusion: { in: %w[reserved settled uncertain cancelled] }
  validates :reserved_ticks, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :charged_ticks, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  after_create_commit :record_ai_attempt
  after_update_commit :record_ai_resolution

  def activity_workspace
    professional_profile&.workspace || project_intake&.workspace
  end

  def record_ai_attempt
    Activity::Recorder.record!(workspace: activity_workspace, subject: self,
      kind: "ai_attempted", title: operation, metadata: { "operation" => operation, "status" => status },
      occurred_at: created_at)
    # Existing providers sometimes create a fully settled ledger row in a single
    # insert rather than transitioning through reserved. Capture that too.
    kind = { "settled" => "ai_settled", "uncertain" => "ai_uncertain",
             "cancelled" => "ai_cancelled" }[status]
    Activity::Recorder.record!(workspace: activity_workspace, subject: self,
      kind: kind, title: operation, metadata: { "operation" => operation, "status" => status },
      occurred_at: resolved_at || created_at) if kind
  end

  def record_ai_resolution
    return unless saved_change_to_status?
    kind = { "settled" => "ai_settled", "uncertain" => "ai_uncertain",
             "cancelled" => "ai_cancelled" }[status]
    return unless kind
    Activity::Recorder.record!(workspace: activity_workspace, subject: self,
      kind: kind, title: operation, metadata: { "operation" => operation, "status" => status },
      occurred_at: updated_at)
  end

  private

  def exactly_one_subject
    errors.add(:base, "Exactly one AI subject required") if project_intake_id.present? == professional_profile_id.present?
  end

end
