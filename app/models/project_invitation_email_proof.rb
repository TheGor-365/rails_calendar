class ProjectInvitationEmailProof < ApplicationRecord
  belongs_to :project_invitation

  MAX_ATTEMPTS = 5

  validates :challenge_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :failed_attempts, numericality: { only_integer: true, in: 0..MAX_ATTEMPTS }
  validates :expires_at, presence: true

  def verified?
    verified_at.present?
  end

  # Email possession proof is NOT an authenticated account, a KYC decision,
  # invitation acceptance, tenant membership, or consent.
  def access_granted?
    false
  end
end
