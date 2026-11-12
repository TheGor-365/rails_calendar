# Production signup requires a separately approved legal notice AND working SMTP.
# Feature flag alone can never enable a public paid-client identity flow.
class ClientSignupAvailability
  REQUIRED_PRODUCTION_KEYS = %w[
    RC_SMTP_ADDRESS RC_SMTP_USERNAME RC_SMTP_PASSWORD
    RC_SIGNUP_FROM
  ].freeze

  def self.enabled?
    return false unless ENV["RC_CLIENT_SIGNUP_ENABLED"] == "true"
    return true unless Rails.env.production?

    ENV["RC_SIGNUP_LEGAL_APPROVED"] == "true" &&
      REQUIRED_PRODUCTION_KEYS.all? { |name| ENV[name].present? }
  end
end
