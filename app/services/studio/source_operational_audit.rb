module Studio
  # Explicit, read-only local audit. This is NOT monitoring until a scheduler,
  # alert destination and run history are deployed and verified.
  class SourceOperationalAudit
    MAX_AGE_WARNING = 15.minutes
    RETENTION_LAG_WARNING = 1.hour

    def initialize(actor:, workspace:, scanner: nil)
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      raise SecurityError, "Synthetic diagnostics only" unless PrivateSourceStorage.enabled?
      @scanner = scanner || ClamAvScanner.new
    end

    def call
      @access.assert_owner!
      now = Time.current
      tasks = @workspace.studio_source_scan_tasks
      counts = Studio::SourceScanTask::STATES.index_with { 0 }
      counts.merge!(tasks.group(:state).count)

      due = tasks.due(now)
      oldest = due.minimum(:next_attempt_at)
      expired = @workspace.project_source_blobs
                          .where("expires_at <= ?", now)
                          .where.not(scan_state: "revoked")
      {
        queue: {
          states: counts,
          due: due.count,
          overdue_15m: due.where("next_attempt_at <= ?", now - MAX_AGE_WARNING).count,
          oldest_due_age_seconds: oldest ? [(now - oldest).to_i, 0].max : nil,
          exhausted: counts.fetch("exhausted")
        },
        storage_metadata: {
          expired_not_revoked: expired.count,
          overdue_expiry_1h: expired.where("expires_at <= ?", now - RETENTION_LAG_WARNING).count,
          failed_scans: @workspace.project_source_blobs.where(scan_state: "failed").count,
          revoked_audit_rows: @workspace.project_source_blobs.where(scan_state: "revoked").count
        },
        clamav: {
          connectivity_and_db_timestamp: scanner_readiness,
          official_signature_provenance_verified: false
        },
        continuous_monitoring_enabled: false,
        production_ready: false
      }
    end

    private

    def scanner_readiness
      @scanner.readiness! == true ? "ready" : "unavailable"
    rescue StandardError
      "unavailable"
    end
  end
end
