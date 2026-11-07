# Single-administrator session authentication for this demonstration app.
# Credentials come exclusively from deployment secrets; missing settings deny access.
module AdminAuthentication
  extend ActiveSupport::Concern

  SESSION_LIFETIME = 8.hours

  included do
    helper_method :admin_signed_in?
  end

  private

  def admin_signed_in?
    return false unless admin_credentials_configured?

    issued_at = session[:admin_signed_in_at]
    return false unless issued_at.is_a?(Integer)

    age = Time.current.to_i - issued_at
    return false unless age >= 0 && age < SESSION_LIFETIME.to_i

    signature = session[:admin_session_signature].to_s
    ActiveSupport::SecurityUtils.secure_compare(signature, admin_session_signature)
  end

  def admin_credentials_configured?
    admin_username.present? && admin_password.present?
  end

  def valid_admin_credentials?(submitted_username, submitted_password)
    return false unless admin_credentials_configured?

    # Compare fixed-length digests to avoid leaking the username via a
    # short-circuiting string comparison.
    username_matches = secure_digest_match?(submitted_username, admin_username)
    password_matches = secure_digest_match?(submitted_password, admin_password)
    username_matches & password_matches
  end

  def secure_digest_match?(submitted, expected)
    submitted_digest = Digest::SHA256.hexdigest(submitted.to_s)
    expected_digest = Digest::SHA256.hexdigest(expected)
    ActiveSupport::SecurityUtils.secure_compare(submitted_digest, expected_digest)
  end

  def admin_username
    ENV["RAILS_CALENDAR_ADMIN_USERNAME"].to_s
  end

  def admin_password
    ENV["RAILS_CALENDAR_ADMIN_PASSWORD"].to_s
  end

  def admin_session_signature
    # Changing either credential or Rails' secret_key_base invalidates
    # existing encrypted-cookie sessions. Never store the raw password.
    OpenSSL::HMAC.hexdigest(
      "SHA256",
      Rails.application.secret_key_base,
      [admin_username, admin_password].join("\0")
    )
  end

  # The development/test demo may use fictional public consultations.
  # In production, existing consultation details are private by default.
  # Explicit opt-in to public demo visibility is intended ONLY for synthetic
  # records that the owner has approved for public display.
  def calendar_public_read_enabled?
    flag = ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"]
    return flag == "true" unless flag.nil?

    !Rails.env.production?
  end

  def require_calendar_read_access!
    return if admin_signed_in? || calendar_public_read_enabled?

    redirect_to admin_login_path, alert: "Administrator sign-in required to view calendar"
  end

  def require_admin!
    return if admin_signed_in?

    redirect_to admin_login_path, alert: "Administrator sign-in required"
  end
end
