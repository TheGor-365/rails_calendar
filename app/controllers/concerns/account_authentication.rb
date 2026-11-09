# Owner accounts use a DB-backed, revocable session. Only a SHA-256 token
# digest is stored in PostgreSQL; the random bearer token lives in the Rails
# encrypted session cookie (CSRF/session protections remain enabled).
module AccountAuthentication
  extend ActiveSupport::Concern

  OWNER_SESSION_LIFETIME = 8.hours

  included do
    helper_method :current_user, :owner_signed_in?
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    token = session[:owner_session_token].to_s
    return @current_user = nil unless token.match?(/\A[0-9a-f]{64}\z/)

    record = UserSession.includes(:user).find_by(token_digest: Digest::SHA256.hexdigest(token))
    @current_user = record&.active? ? record.user : nil
  end

  def owner_signed_in?
    current_user&.role == "owner"
  end

  def start_owner_session!(user)
    reset_session
    token = SecureRandom.hex(32)
    user.user_sessions.create!(
      token_digest: Digest::SHA256.hexdigest(token),
      expires_at: OWNER_SESSION_LIFETIME.from_now
    )
    session[:owner_session_token] = token
    @current_user = user
  end

  def end_owner_session!
    token = session[:owner_session_token].to_s
    if token.match?(/\A[0-9a-f]{64}\z/)
      UserSession.where(token_digest: Digest::SHA256.hexdigest(token)).delete_all
    end
    reset_session
    @current_user = nil
  end
end
