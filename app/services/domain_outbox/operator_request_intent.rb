module DomainOutbox
  # Future owner POST idempotency intent. Prepared only by an explicitly
  # invoked controller action (none is routed today), never by a queue GET.
  # State resides in Rails' encrypted/signed session, not in PostgreSQL.
  # It does NOT authorize a replay without Rails CSRF + owner session checks.
  class OperatorRequestIntent
    SESSION_KEY = "rc_owner_outbox_replay_intent_v1"
    VALID_FOR = 10.minutes
    TOKEN_FORMAT = /\A[0-9a-f]{64}\z/

    # Creates an opaque form token scoped to one owner/workspace/limit.
    # A future form must submit this exact token back; no token is logged.
    def self.prepare!(session:, owner:, limit:, now: Time.current)
      workspace = OperatorAccess.workspace_for!(owner: owner)
      allowed = OperatorAccess.replay_limit!(limit: limit)
      require_time!(now)

      token = SecureRandom.hex(32)
      session[SESSION_KEY] = {
        "token" => token,
        "owner_user_id" => owner.id,
        "workspace_id" => workspace.id,
        "limit" => allowed,
        "issued_at" => now.to_i
      }
      token
    end

    # Validation is read-only. It deliberately does not consume the intent:
    # a browser retry sends the same token, so the durable journal's unique
    # request digest can correctly return "duplicate" instead of replaying.
    def self.verify!(session:, owner:, request_token:, limit:, confirmation:, now: Time.current)
      authority = OperatorConfirmation.validate!(
        owner: owner, limit: limit, confirmation: confirmation
      )
      require_time!(now)

      intent = session[SESSION_KEY]
      unless intent.is_a?(Hash) &&
          intent["owner_user_id"] == owner.id &&
          intent["workspace_id"] == authority.fetch(:workspace).id &&
          intent["limit"] == authority.fetch(:limit) &&
          intent["issued_at"].is_a?(Integer) &&
          intent["token"].is_a?(String) && TOKEN_FORMAT.match?(intent["token"]) &&
          request_token.is_a?(String) && TOKEN_FORMAT.match?(request_token)
        raise ArgumentError, "invalid supervised replay session intent"
      end

      age = now.to_i - intent.fetch("issued_at")
      unless age >= 0 && age <= VALID_FOR.to_i &&
          ActiveSupport::SecurityUtils.secure_compare(intent.fetch("token"), request_token)
        raise ArgumentError, "expired or mismatched supervised replay session intent"
      end

      # ONLY an authenticated, CSRF-protected future controller may pass
      # this result to SupervisedReplay.run!, never a public GET or client.
      authority.merge(request_token: request_token)
    end

    def self.require_time!(value)
      return if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      raise ArgumentError, "valid timestamp required"
    end
    private_class_method :require_time!
  end
end
