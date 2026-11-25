module DomainOutbox
  # Read-only triage of an unfinished supervised replay.
  #
  # Old age alone NEVER proves a worker is dead, nor authorizes resuming,
  # deleting a journal row, resetting an event, or starting another replay.
  # There is deliberately no recovery mutator, HTTP route or scheduler.
  class RecoveryInspection
    REVIEW_AFTER = 15.minutes

    def self.snapshot(owner:, now: Time.current)
      workspace = OperatorAccess.workspace_for!(owner: owner)
      unless now.is_a?(Time) || now.is_a?(ActiveSupport::TimeWithZone)
        raise ArgumentError, "valid timestamp required"
      end

      running = OwnerOutboxReplayRun
        .where(workspace_id: workspace.id, state: "running")
        .order(started_at: :asc, id: :asc)
        .first

      return { status: "no_running_command", manual_review_required: false } unless running

      elapsed = now - running.started_at
      # A negative elapsed value is a clock anomaly, NOT evidence of safety.
      review = elapsed.negative? || elapsed >= REVIEW_AFTER

      {
        status: review ? "manual_review_required" : "in_progress",
        manual_review_required: review
      }
    end
  end
end
