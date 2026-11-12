# Local-only product pilot. Intentionally cannot expose client intake in production.
class ClientRequestPilot
  def self.enabled?(request:)
    (Rails.env.development? || Rails.env.test?) &&
      request.local? &&
      ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] == "true"
  end
end
