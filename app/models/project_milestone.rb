# This date-only proposal is private to one intake and not a booked consultation.
class ProjectMilestone < ApplicationRecord
  belongs_to :project_intake
  belongs_to :intake_spec_version

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 240 }
  validates :suggested_work_days, numericality: { only_integer: true, in: 1..30 }
  validates :status, inclusion: { in: %w[proposed accepted in_progress completed] }
  validates :start_on, :end_on, presence: true
  validate :end_not_before_start
  validate :version_belongs_to_intake

  private

  def end_not_before_start
    errors.add(:end_on, "cannot precede start_on") if start_on && end_on && end_on < start_on
  end

  def version_belongs_to_intake
    return if intake_spec_version.blank? || project_intake.blank?
    unless intake_spec_version.project_intake_id == project_intake.id
      errors.add(:intake_spec_version, "must belong to the same intake")
    end
  end
end
