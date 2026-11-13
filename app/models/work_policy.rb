class WorkPolicy < ApplicationRecord
  belongs_to :professional_profile

  validates :snapshot_version, numericality: { only_integer: true, greater_than: 0 },
                               uniqueness: { scope: :professional_profile_id }
  before_update { raise ActiveRecord::ReadOnlyError, "Approved policies are immutable" }
  before_destroy { raise ActiveRecord::ReadOnlyError, "Approved policies are immutable" }
end
