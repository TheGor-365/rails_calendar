class ProjectIntake < ApplicationRecord
  TYPES = %w[website redesign rails_bugfix api_integration].freeze
  STATUSES = %w[interviewing draft_spec owner_approved client_reviewed].freeze
  MAX_CLIENT_MESSAGES = 8

  has_many :intake_messages, dependent: :restrict_with_exception
  has_many :intake_answers, dependent: :restrict_with_exception
  has_many :intake_spec_versions, dependent: :restrict_with_exception
  has_many :project_milestones, dependent: :restrict_with_exception

  validates :title, presence: true, length: { maximum: 120 }
  validates :project_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :goal, presence: true, length: { minimum: 10, maximum: 3000 }
  validates :demo_consent_at, presence: true

  def latest_spec
    intake_spec_versions.order(version: :desc).first
  end

  def published_spec
    intake_spec_versions.where.not(owner_approved_at: nil).order(version: :desc).first
  end

  def client_message_count
    intake_messages.where(role: "client").count
  end
end
