module Studio
  # A single explicit LOCAL tick is idempotent per time slot.
  # There is NO timer/cron/worker deployed. Ambiguous crashes stay "running"
  # and block subsequent slots: never automatically replay side effects.
  class SourceMaintenanceScheduler
    PERIOD = { "health" => 5.minutes.to_i, "scan" => 5.minutes.to_i,
               "retention" => 1.hour.to_i, "inventory" => 1.day.to_i }.freeze
    class Disabled < StandardError; end

    def initialize(actor:, workspace:, executor: nil)
      @workspace = workspace
      @actor = actor
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      raise Disabled, "Synthetic local-only maintenance" unless PrivateSourceStorage.enabled?
      @executor = executor
    end

    def tick!(kind:, allow_retention: false, now: Time.current)
      @access.assert_owner!
      raise ArgumentError, "Unknown maintenance operation" unless PERIOD.key?(kind)
      # Physical cleanup is never permitted merely by ticking the scheduler.
      if kind == "retention" && !(allow_retention &&
          Rails.env.development? && ENV["RC_STUDIO_ALLOW_LOCAL_PURGE"] == "true")
        raise Disabled, "Physical cleanup requires separate local approval"
      end
      if kind == "inventory" && !PrivateSourceStorage.s3_backend?
        raise Disabled, "Inventory requires synthetic S3 backend"
      end

      slot = now.to_i / PERIOD.fetch(kind)
      scope = @workspace.studio_maintenance_runs
      run = nil
      claimed = false
      @workspace.with_lock do
        @access.assert_owner!
        run = scope.find_by(kind: kind, slot: slot)
        unless run
          # A process may have crashed after claim. NEVER auto-replay work
          # while ownership of previous side effects is unknown.
          if !scope.where(kind: kind, state: "running").exists?
            run = scope.create!(kind: kind, slot: slot, started_at: Time.current)
            claimed = true
          end
        end
      end
      return run unless claimed

      execute_claimed!(run, kind)
    end

    private

    def execute_claimed!(run, kind)
      @access.assert_owner!
      summary = case kind
      when "health"
        report = @executor ? @executor.call(kind) :
          SourceOperationalAudit.new(actor: @actor, workspace: @workspace).call
        { queue_due: report.dig(:queue, :due).to_i,
          retention_overdue: report.dig(:storage_metadata, :overdue_expiry_1h).to_i,
          clamav_ready: report.dig(:clamav, :connectivity_and_db_timestamp) == "ready" }
      when "scan"
        { processed: (@executor ? @executor.call(kind) :
          SourceScanQueue.new(actor: @actor, workspace: @workspace).process_due!(limit: 5)).to_i }
      when "retention"
        { physically_deleted: (@executor ? @executor.call(kind) :
          ProjectSourceRetention.new(actor: @actor, workspace: @workspace).sweep_expired!(limit: 20)).to_i }
      when "inventory"
        report = @executor ? @executor.call(kind) :
          SourceInventoryReconciliation.new(actor: @actor, workspace: @workspace).call
        { pages: report.fetch(:pages).to_i,
          complete: report.fetch(:reconciliation_complete) == true,
          orphan_candidates_review_only: report.dig(:counts, :orphan_candidates_review_only).to_i,
          missing_objects: report.dig(:counts, :db_missing_objects).to_i }
      end
      run.update!(state: "succeeded", finished_at: Time.current, result_summary: summary)
      run
    rescue StandardError, SecurityError
      # No original error messages, keys, filenames or vendor responses in DB.
      run.update!(state: "failed", finished_at: Time.current, error_code: "operation_failed")
      run
    end
  end
end
