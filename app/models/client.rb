class Client < ApplicationRecord
  belongs_to :workspace
  has_many :client_facts, dependent: :restrict_with_exception
  has_many :project_intakes, dependent: :restrict_with_exception
  has_many :project_sources, dependent: :restrict_with_exception
  has_many :project_invitations, dependent: :restrict_with_exception
  has_many :client_consents, dependent: :restrict_with_exception

  STATUSES = %w[prospect active inactive].freeze

  validates :display_name, presence: true, length: { maximum: 120 }
  validates :status, inclusion: { in: STATUSES }
end
