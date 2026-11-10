class WorkspaceMembership < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  ROLES = %w[owner manager developer client].freeze
  STATUSES = %w[invited active suspended revoked].freeze

  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :workspace_id }
  validate :validate_owner_membership

  private

  def validate_owner_membership
    return unless role == "owner"
    unless user&.role == "owner" && workspace&.owner_user_id == user_id
      errors.add(:role, "must correspond to the workspace owner")
    end
  end
end
