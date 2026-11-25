module DomainOutbox
  # Explicit, non-public server command. It is not a route, job or scheduler:
  # a future authenticated owner POST must separately review CSRF, UX and rate
  # policy before this service is made reachable by users.
  class SupervisedReplay
    COOLDOWN = 60.seconds
    TOKEN_FORMAT = /\A[0-9a-f]{64}\z/
    class InvalidSummary < StandardError; end

    # request_token must be newly generated high-entropy lowercase hex.
    # It is never saved; only a workspace-scoped SHA256 digest is persisted.
    # The caller must supply an explicitly authenticated owner user.
    def self.run!(owner:, request_token:, limit:, confirmed:, now: Time.current)
      raise ArgumentError, "explicit confirmation required" unless confirmed == true

      workspace = OperatorAccess.workspace_for!(owner: owner)
      limit = OperatorAccess.replay_limit!(limit: limit)
      unless request_token.is_a?(String) && TOKEN_FORMAT.match?(request_token)
        raise ArgumentError, "opaque 64-character request token required"
      end

      digest = Digest::SHA256.hexdigest(
        "rails-calendar:supervised-replay:v1:#{workspace.id}:#{request_token}"
      )
      run = nil
      decision = nil

      # Lock the workspace, not merely a candidate event, to serialize owner
      # commands BEFORE calling Replayer. Concurrent calls for this tenant
      # cannot both insert a running command. DB uniqueness is a second guard.
      workspace.with_lock do
        existing = OwnerOutboxReplayRun.find_by(workspace_id: workspace.id, request_digest: digest)
        if existing
          decision = :duplicate
        elsif OwnerOutboxReplayRun.exists?(workspace_id: workspace.id, state: "running")
          # Includes crashed/stuck runs: no silent auto-takeover.
          decision = :busy
        else
          last_started = OwnerOutboxReplayRun.where(workspace_id: workspace.id)
            .maximum(:started_at)
          if last_started && now < last_started + COOLDOWN
            decision = :cooldown
          else
            run = OwnerOutboxReplayRun.create!(
              workspace: workspace, owner_user: owner, request_digest: digest,
              state: "running", requested_limit: limit, started_at: now
            )
          end
        end
      end

      return response(decision) if decision

      begin
        summary = Replayer.run!(workspace: workspace, limit: limit, now: now)
        unless valid_summary?(summary, limit: limit)
          raise InvalidSummary, "replayer returned invalid aggregate counts"
        end

        run.update!(
          state: "succeeded", finished_at: Time.current,
          attempted_count: summary.fetch(:attempted),
          delivered_count: summary.fetch(:delivered),
          failed_count: summary.fetch(:failed)
        )
        response(:succeeded, summary)
      rescue StandardError => error
        # No exception message, identifiers, source payload or provider data.
        # If even the journal write fails, leave the running row untouched:
        # it blocks further commands pending explicit manual investigation.
        safe_code = error.class.name.to_s.presence || "UnknownError"
        run.update!(
          state: "failed", finished_at: Time.current,
          error_code: safe_code.truncate(80)
        )
        response(:failed)
      end
    end

    def self.valid_summary?(summary, limit:)
      return false unless summary.is_a?(Hash) &&
        summary.keys.sort == %i[attempted delivered failed].sort

      counts = summary.values
      counts.all? { |value| value.is_a?(Integer) && value >= 0 } &&
        summary[:attempted] <= limit &&
        summary[:delivered] + summary[:failed] <= summary[:attempted]
    end
    private_class_method :valid_summary?

    def self.response(status, summary = {})
      {
        status: status.to_s,
        attempted: summary.fetch(:attempted, 0),
        delivered: summary.fetch(:delivered, 0),
        failed: summary.fetch(:failed, 0)
      }
    end
    private_class_method :response
  end
end
