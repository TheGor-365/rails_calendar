module Studio
  # Explicit operator attestation to close an ABANDONED local run.
  # Never runs the abandoned operation, never cleans S3 objects and
  # never reclaims running work by timeout alone.
  class OperatorRecovery
    class Denied < StandardError; end
    MIN_AGE = 30.minutes
    REASON_FOR = {
      "health" => "health_inspected",
      "inventory" => "inventory_inspected",
      "scan" => "scan_tasks_inspected",
      "retention" => "retention_objects_inspected"
    }.freeze

    def initialize(actor:, workspace:)
      @actor = actor
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      raise Denied, "Only synthetic local recovery allowed" unless self.class.enabled?
    end

    def self.enabled?
      Rails.env.test? || (Rails.env.development? &&
        ENV["RC_STUDIO_SYNTHETIC_STORAGE"] == "true" &&
        ENV["RC_STUDIO_OPERATOR_RECOVERY"] == "true")
    end

    def close_abandoned!(run_id:, reason_code:, confirmation:)
      @access.assert_owner!
      raise Denied, "Explicit review code required" unless
        confirmation == "REVIEWED-RUN-#{run_id}"
      result = nil
      @workspace.with_lock do
        @access.assert_owner!
        run = @workspace.studio_maintenance_runs.find_by(id: run_id)
        raise Denied, "Unknown maintenance run" unless run
        run.lock!
        raise Denied, "Not an abandoned operation" unless
          run.state == "running" && run.started_at <= MIN_AGE.ago
        raise Denied, "Review reason does not match operation" unless
          reason_code == REASON_FOR.fetch(run.kind)
        # Receipt and final state are an indivisible DB transaction.
        review = Studio::OperatorReview.create!(
          workspace: @workspace, maintenance_run: run,
          reviewed_by: @actor, reason_code: reason_code,
          reviewed_at: Time.current
        )
        run.update!(state: "failed", error_code: "operation_failed",
                    finished_at: Time.current, result_summary: {})
        result = review
      end
      result
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      raise Denied, "Recovery review rejected"
    end
  end
end
