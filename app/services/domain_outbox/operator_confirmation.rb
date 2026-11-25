module DomainOutbox
  # HTTP-boundary validation only for a FUTURE, separately approved owner POST.
  # Does not generate a replay token, write audit rows or call Replayer.
  # CSRF/session authentication still belongs to the future controller.
  class OperatorConfirmation
    ALLOWED_HTTP_LIMITS = %w[1 5 10 25].freeze

    def self.validate!(owner:, limit:, confirmation:)
      workspace = OperatorAccess.workspace_for!(owner: owner)

      unless limit.is_a?(String) && ALLOWED_HTTP_LIMITS.include?(limit)
        raise ArgumentError, "invalid supervised HTTP replay limit"
      end

      unless confirmation.is_a?(String) && confirmation == "REPLAY #{limit}"
        raise ArgumentError, "exact human confirmation required"
      end

      # Important: workspace is obtained from the signed-in owner, not params.
      { workspace: workspace, limit: OperatorAccess.replay_limit!(limit: limit.to_i) }
    end
  end
end
