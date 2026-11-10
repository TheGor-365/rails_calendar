module Studio
  # Synchronous, bounded cleanup of expired *synthetic* quarantine bytes.
  # No production cleanup is available until a durable store, retention
  # policy, audit, and independent recovery design have been approved.
  class ProjectSourceRetention
    MAX_BATCH = 50

    def initialize(actor:, workspace:, storage: nil)
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      @storage = storage || PrivateSourceStorage.new
    end

    def sweep_expired!(limit: MAX_BATCH)
      @access.assert_owner!
      raise ArgumentError, "Invalid cleanup limit" unless limit.is_a?(Integer) && limit.between?(1, MAX_BATCH)
      raise PrivateSourceStorage::Unavailable, "Synthetic cleanup only" unless PrivateSourceStorage.enabled?

      candidates = @workspace.project_source_blobs
                             .where("expires_at <= ?", Time.current)
                             .where.not(scan_state: "revoked")
                             .order(:expires_at, :id).limit(limit).to_a
      candidates.each do |blob|
        @access.assert_owner!
        # An S3/Disk failure aborts without marking metadata as cleaned up.
        @storage.delete!(key: blob.object_key)
        blob.update!(scan_state: "revoked")
      end
      candidates.length
    end
  end
end
