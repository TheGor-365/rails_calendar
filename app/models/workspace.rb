class Workspace < ApplicationRecord
  belongs_to :owner_user, class_name: "User"
  has_many :workspace_memberships, dependent: :restrict_with_exception
  has_many :clients, dependent: :restrict_with_exception
  has_many :project_intakes, dependent: :restrict_with_exception
  has_many :studio_ai_policies, class_name: "Studio::AiPolicy", dependent: :restrict_with_exception
  has_many :studio_offline_runs, class_name: "Studio::OfflineRun", dependent: :restrict_with_exception
  has_many :studio_offline_run_reviews, class_name: "Studio::OfflineRunReview",
           dependent: :restrict_with_exception
  has_many :studio_ai_policy_revisions, class_name: "Studio::AiPolicyRevision",
           dependent: :restrict_with_exception
  has_many :project_sources, dependent: :restrict_with_exception
  has_many :project_source_blobs, dependent: :restrict_with_exception
  has_many :studio_source_scan_tasks, class_name: "Studio::SourceScanTask",
           dependent: :restrict_with_exception
  has_many :studio_maintenance_runs, class_name: "Studio::MaintenanceRun",
           dependent: :restrict_with_exception
  has_many :studio_operator_reviews, class_name: "Studio::OperatorReview",
           dependent: :restrict_with_exception
  has_many :studio_inventory_checkpoints, class_name: "Studio::InventoryCheckpoint",
           dependent: :restrict_with_exception
  has_many :project_invitations, dependent: :restrict_with_exception
  has_many :client_facts, dependent: :restrict_with_exception
  has_many :client_consents, dependent: :restrict_with_exception

  STATES = %w[internal suspended].freeze

  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, length: { maximum: 64 },
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ },
                   uniqueness: true
  validates :state, inclusion: { in: STATES }

  # Membership must be explicit; owning a workspace alone grants no access
  # to a caller without an active membership.
  def owner_access?(actor)
    actor.is_a?(User) && actor.persisted? && actor.role == "owner" &&
      actor.id == owner_user_id && state == "internal" &&
      workspace_memberships.where(user_id: actor.id, role: "owner", status: "active").exists?
  end
end
