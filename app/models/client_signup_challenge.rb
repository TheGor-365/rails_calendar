# Pending identity, never an authenticated user. No plaintext password or OTP is stored.
class ClientSignupChallenge < ApplicationRecord
  has_secure_password validations: false

  CODE_TTL = 10.minutes
  RESEND_COOLDOWN = 60.seconds
  MAX_SENDS_PER_HOUR = 3
  MAX_FAILURES = 5

  normalizes :email, with: ->(value) { value.strip.downcase }
  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :password_digest, :code_digest, :expires_at, :sent_at, :consent_at, :window_started_at, presence: true
  validates :code_digest, format: { with: /\A[0-9a-f]{64}\z/ }

  def self.digest_for(email, code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "rc-signup-v1:#{email}:#{code}")
  end

  def code_matches?(code)
    code.match?(/\A\d{6}\z/) &&
      ActiveSupport::SecurityUtils.secure_compare(code_digest, self.class.digest_for(email, code))
  end
end
