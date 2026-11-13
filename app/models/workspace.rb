class Workspace < ApplicationRecord
  belongs_to :owner_user, class_name: "User"
  has_one :professional_profile, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 120 }
  validates :owner_user_id, uniqueness: true
  validate :owner_role

  private

  def owner_role
    errors.add(:owner_user, "must have owner role") unless owner_user&.role == "owner"
  end
end
