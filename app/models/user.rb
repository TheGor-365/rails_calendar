class User < ApplicationRecord
  has_secure_password
  has_many :user_sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, length: { maximum: 254 },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: %w[owner] }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
end
