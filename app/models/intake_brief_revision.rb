# Append-only snapshots of the shared, client-facing technical choices.
# Owner seed is never overwritten when the client submits a clarification.
class IntakeBriefRevision < ApplicationRecord
  belongs_to :project_intake

  ROLES = %w[owner client].freeze

  validates :version, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :project_intake_id }
  validates :author_role, inclusion: { in: ROLES }
  validates :notes, length: { maximum: 350 }
  validate :allowed_brief_choices

  def readonly?
    persisted?
  end

  private

  def allowed_brief_choices
    errors.add(:selections, "contains unsupported choices") unless InvitationBriefTaxonomy.valid?(selections)
    errors.add(:decisions, "contains unsupported choices") unless InvitationBriefTaxonomy.valid_decisions?(decisions)
  end
end
