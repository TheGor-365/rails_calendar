module Studio
  # Read-only owner/tenant operator report. NO recovery, retry, cursor step or deletion.
  class SourceOperatorDashboard
    def initialize(actor:, workspace:, scanner: nil)
      @workspace, @actor, @scanner = workspace, actor, scanner
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      raise SecurityError, "Synthetic diagnostics only" unless PrivateSourceStorage.enabled?
    end

    def call
      @access.assert_owner!
      now = Time.current
      runs = @workspace.studio_maintenance_runs
      checkpoints = @workspace.studio_inventory_checkpoints
      running = runs.where(state: "running")
      abandoned = running.where("started_at <= ?", now - 30.minutes)
      incomplete = checkpoints.where(state: %w[listing checking])
      {
        operational: SourceOperationalAudit.new(
          actor: @actor, workspace: @workspace, scanner: @scanner).call,
        maintenance: {
          running_by_kind: grouped(running),
          abandoned_over_30m_by_kind: grouped(abandoned),
          failed_by_kind: grouped(runs.where(state: "failed")),
          manual_review_required: abandoned.exists?,
          replay_permitted: false, automatic_recovery_enabled: false
        },
        inventory_checkpoints: {
          state_counts: Studio::InventoryCheckpoint::STATES.index_with { |state|
            checkpoints.where(state: state).count
          },
          incomplete: incomplete.count,
          expired_incomplete: incomplete.where("expires_at <= ?", now).count,
          snapshot_consistent: false, orphan_deletion_permitted: false,
          raw_keys_exported: false, raw_cursors_exported: false
        },
        read_only: true, production_ready: false
      }
    end

    private

    def grouped(relation)
      Studio::MaintenanceRun::KINDS.index_with { |kind| relation.where(kind: kind).count }
    end
  end
end
