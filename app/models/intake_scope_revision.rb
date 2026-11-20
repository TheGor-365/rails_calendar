# Append-only account-owned snapshots of the 12-part discovery questionnaire.
# These are *inputs* to a future specification, not an approved contract.
class IntakeScopeRevision < ApplicationRecord
  belongs_to :project_intake

  validates :version, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :project_intake_id }
  validates :author_role, inclusion: { in: %w[owner client] }
  validate :supported_answers

  def readonly?
    persisted?
  end

  private

  def supported_answers
    errors.add(:answers, "contains unsupported sections or statuses") unless IntakeScopeSections.normalize(answers)
  end
end
