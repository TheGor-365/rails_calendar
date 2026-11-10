class ClientConsent < ApplicationRecord
  belongs_to :workspace
  belongs_to :client
  belongs_to :recorded_by, class_name: "User"

  PURPOSES = %w[discovery delivery support external_ai].freeze

  validates :purpose, inclusion: { in: PURPOSES }
  validates :granted, inclusion: { in: [true, false] }
  validates :source_ref, presence: true, length: { maximum: 160 }
  validate :matching_tenant

  before_update :reject_mutation
  before_destroy :reject_mutation

  private

  def matching_tenant
    errors.add(:workspace_id, "does not match client") if client && workspace_id != client.workspace_id
  end

  def reject_mutation
    errors.add(:base, "Consent events are append-only")
    throw :abort
  end
end
