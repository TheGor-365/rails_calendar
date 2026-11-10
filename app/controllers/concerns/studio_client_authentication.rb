module StudioClientAuthentication
  extend ActiveSupport::Concern

  CLIENT_SESSION_LIFETIME = 4.hours

  included { helper_method :current_studio_client }

  private

  def current_studio_client
    return @current_studio_client if defined?(@current_studio_client)
    return @current_studio_client = nil unless Studio::ClientOnboarding.enabled?

    token = session[:studio_client_session_token].to_s
    return @current_studio_client = nil unless token.match?(/\A[0-9a-f]{64}\z/)

    record = Studio::ClientSession.includes(:client_account)
      .find_by(token_digest: Digest::SHA256.hexdigest(token))
    @current_studio_client = record&.active? ? record.client_account : nil
  end

  def start_studio_client_session!(account)
    raise SecurityError, "Client onboarding disabled" unless Studio::ClientOnboarding.enabled?
    reset_session
    token = SecureRandom.hex(32)
    account.client_sessions.create!(
      token_digest: Digest::SHA256.hexdigest(token),
      expires_at: CLIENT_SESSION_LIFETIME.from_now
    )
    session[:studio_client_session_token] = token
    @current_studio_client = account
    @current_user = nil
  end

  def end_studio_client_session!
    token = session[:studio_client_session_token].to_s
    if token.match?(/\A[0-9a-f]{64}\z/)
      Studio::ClientSession.where(token_digest: Digest::SHA256.hexdigest(token)).delete_all
    end
    reset_session
    @current_studio_client = nil
    @current_user = nil
  end
end
