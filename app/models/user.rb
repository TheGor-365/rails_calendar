class User < ApplicationRecord
  has_secure_password
  has_many :user_sessions, dependent: :destroy
  has_one :owner_workspace, class_name: "Workspace", foreign_key: :owner_user_id, inverse_of: :owner_user, dependent: :restrict_with_exception
  has_many :client_project_intakes, class_name: "ProjectIntake", foreign_key: :client_user_id, inverse_of: :client_user, dependent: :restrict_with_exception

  def verified_client?
    role == "client" && email_verified_at.present?
  end

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, length: { maximum: 254 },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: %w[owner client] }
  validates :email_verified_at, :signup_consent_at, :signup_policy_version, presence: true, if: -> { role == "client" }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
end
