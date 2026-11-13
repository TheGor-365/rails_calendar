class ProfessionalContextSnapshot < ApplicationRecord
  belongs_to :professional_profile

  validates :version, numericality: { only_integer: true, greater_than: 0 },
                      uniqueness: { scope: :professional_profile_id }
  validates :digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :approved_at, presence: true

  before_update { raise ActiveRecord::ReadOnlyError, "Approved context is immutable" }
  before_destroy { raise ActiveRecord::ReadOnlyError, "Approved context is immutable" }
end
