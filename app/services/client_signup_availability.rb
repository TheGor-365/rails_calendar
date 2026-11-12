# Production signup requires a separately approved legal notice AND working SMTP.
# Feature flag alone can never enable a public paid-client identity flow.
class ClientSignupAvailability
  REQUIRED_PRODUCTION_KEYS = %w[
    RC_SMTP_ADDRESS RC_SMTP_USERNAME RC_SMTP_PASSWORD
    RC_SIGNUP_FROM RC_SIGNUP_PRIVACY_URL RC_SIGNUP_POLICY_VERSION
  ].freeze

  def self.policy_version
    Rails.env.production? ? ENV["RC_SIGNUP_POLICY_VERSION"].to_s : "qa-2026-11-12"
  end

  def self.privacy_url
    if Rails.env.production?
      ENV.fetch("RC_SIGNUP_PRIVACY_URL", "")
    else
      "/register/privacy"
    end
  end

  def self.enabled?
    return false unless ENV["RC_CLIENT_SIGNUP_ENABLED"] == "true"
    return true unless Rails.env.production?

    port = Integer(ENV.fetch("RC_SMTP_PORT", "587"), exception: false)
    ENV["RC_SIGNUP_LEGAL_APPROVED"] == "true" &&
      port&.between?(1, 65_535) &&
      REQUIRED_PRODUCTION_KEYS.all? { |name| ENV[name].present? } &&
      ENV["RC_SIGNUP_POLICY_VERSION"].match?(/\A[a-zA-Z0-9_.:-]{4,80}\z/) &&
      ENV["RC_SIGNUP_PRIVACY_URL"].match?(/\Ahttps:\/\/[^\s]+\z/)
  end
end
