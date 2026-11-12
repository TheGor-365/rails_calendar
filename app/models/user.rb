class User < ApplicationRecord
  has_secure_password
  has_many :user_sessions, dependent: :destroy

  def verified_client?
    role == "client" && email_verified_at.present?
  end

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, length: { maximum: 254 },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: %w[owner client] }
  validates :email_verified_at, :signup_consent_at, presence: true, if: -> { role == "client" }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
end
