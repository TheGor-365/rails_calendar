class ProfessionalCapability < ApplicationRecord
  belongs_to :professional_profile

  validates :domain, presence: true, length: { maximum: 80 },
                     uniqueness: { scope: [:professional_profile_id, :snapshot_version] }
  validates :snapshot_version, numericality: { only_integer: true, greater_than: 0 }
  validates :delivery_mode, inclusion: { in: %w[direct ai_assisted evaluate_first excluded] }
  validates :experience_claim, inclusion: { in: %w[practiced learning new_to_me] }
  validates :evidence_status, inclusion: { in: %w[unverified self_reported verified_by_owner linked_evidence] }
  validates :willingness, inclusion: { in: %w[actively_offer consider only_if_simple not_interested] }
  validates :privacy_scope, inclusion: { in: %w[private client_shareable public_approved] }

  before_update { raise ActiveRecord::ReadOnlyError, "Snapshot capabilities are immutable" }
  before_destroy { raise ActiveRecord::ReadOnlyError, "Snapshot capabilities are immutable" }
end
