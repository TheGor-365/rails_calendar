class ProjectInvitation < ApplicationRecord
  belongs_to :workspace
  belongs_to :client
  belongs_to :project_intake
  belongs_to :issued_by, class_name: "User"

  ROLES = %w[reviewer].freeze
  STATES = %w[pending revoked].freeze

  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATES }
  validates :token_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :recipient_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :expires_at, presence: true
  validate :same_tenant
  validate :valid_expiry, on: :create

  before_update :only_allow_revocation
  before_destroy :prevent_destroy

  # A pending token is NOT an authorized client login or approval.
  def redeemable?
    false
  end

  def expired?
    expires_at <= Time.current
  end

  private

  def same_tenant
    if client && client.workspace_id != workspace_id
      errors.add(:client, "is outside workspace")
    end
    if project_intake && (project_intake.workspace_id != workspace_id ||
                          project_intake.client_id != client_id)
      errors.add(:project_intake, "is outside client scope")
    end
  end

  def valid_expiry
    return unless expires_at

    unless expires_at > Time.current && expires_at <= 72.hours.from_now
      errors.add(:expires_at, "must be within 72 hours")
    end
  end

  def only_allow_revocation
    return if (changes_to_save.keys - ["updated_at"]) == ["status"] && status == "revoked"

    errors.add(:base, "Only revocation is allowed")
    throw :abort
  end

  def prevent_destroy
    errors.add(:base, "Invitation records are retained for audit")
    throw :abort
  end
end
