module DomainOutbox
  # C2.3b6a: read-only, owner-authorized queue observability.
  #
  # No endpoints, replay jobs, AI calls or client-visible data are created
  # here. Neither preview nor snapshot reveals source IDs, messages, files,
  # token digests, client names or any outbox metadata.
  class Health
    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    def self.snapshot(owner:, now: Time.current)
      scope = scoped_events(owner)
      states = scope.group(:state).count
      backlog = scope.where(state: %w[pending failed])
      oldest = backlog.minimum(:occurred_at)

      {
        total: states.values.sum,
        states: DomainOutboxEvent::STATES.to_h { |state| [state, states.fetch(state, 0)] },
        due: scope.due(now).count,
        exhausted: scope.where(state: "failed")
          .where("attempts >= ?", DomainOutboxEvent::MAX_ATTEMPTS).count,
        attempts_total: scope.sum(:attempts),
        oldest_undelivered_age_seconds: oldest && [now.to_i - oldest.to_i, 0].max
      }
    end

    # This is a bounded, read-only *candidate* list, not a claim that any
    # source still exists or would pass the replayer's source validation.
    # A later owner-reviewed command can display these values, but neither
    # this service nor its caller may automatically replay anything.
    def self.preview(owner:, limit: DEFAULT_LIMIT, now: Time.current)
      raise ArgumentError, "limit must be 1..100" unless
        limit.is_a?(Integer) && limit.between?(1, MAX_LIMIT)

      scoped_events(owner).due(now).limit(limit).map do |event|
        {
          source_type: event.source_type,
          kind: event.kind,
          source_version: event.source_version,
          attempts: event.attempts,
          age_seconds: [now.to_i - event.occurred_at.to_i, 0].max
        }
      end
    end

    def self.scoped_events(owner)
      workspace = OperatorAccess.workspace_for!(owner: owner)
      DomainOutboxEvent.where(workspace_id: workspace.id)
    end
    private_class_method :scoped_events
  end
end
