class ProjectIntake < ApplicationRecord
  TYPES = %w[website redesign rails_bugfix api_integration].freeze
  STATUSES = %w[interviewing draft_spec owner_approved client_reviewed].freeze
  MAX_CLIENT_MESSAGES = 8

  belongs_to :client_user, class_name: "User", optional: true, inverse_of: :client_project_intakes
  belongs_to :workspace, optional: true
  has_many :intake_messages, dependent: :restrict_with_exception
  has_many :intake_service_selections, dependent: :restrict_with_exception
  has_many :intake_brief_revisions, dependent: :restrict_with_exception
  has_many :intake_scope_revisions, dependent: :restrict_with_exception

  def latest_scope_revision
    intake_scope_revisions.order(version: :desc).first
  end

  def latest_brief_revision
    intake_brief_revisions.order(version: :desc).first
  end
  has_one :client_request_invitation, dependent: :restrict_with_exception
  has_many :selected_service_offering_versions, through: :intake_service_selections, source: :service_offering_version
  has_many :owner_intake_read_states, dependent: :restrict_with_exception
  has_many :intake_answers, dependent: :restrict_with_exception
  has_many :intake_spec_versions, dependent: :restrict_with_exception
  has_many :ai_spend_entries, dependent: :restrict_with_exception
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
