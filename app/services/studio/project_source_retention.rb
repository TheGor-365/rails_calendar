module Studio
  # Synchronous, bounded cleanup of expired *synthetic* quarantine bytes.
  # No production cleanup is available until a durable store, retention
  # policy, audit, and independent recovery design have been approved.
  class ProjectSourceRetention
    MAX_BATCH = 50
    class VerificationFailed < StandardError; end

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
      removed = 0
      candidates.each do |blob|
        @access.assert_owner!
        blob.with_lock do
          # Recheck after row lock: a scan or another cleanup worker may have
          # changed the state. Deleting bytes while holding the same blob lock
          # prevents an in-flight scan from reviving a revoked source.
          next if blob.scan_state == "revoked" || blob.expires_at > Time.current

          # Storage failure prevents any false "deleted" audit conclusion.
          @storage.delete!(key: blob.object_key)
          if @storage.exists?(key: blob.object_key)
            raise VerificationFailed, "Physical object is still present after deletion"
          end
          blob.update!(scan_state: "revoked")
          removed += 1
        end
      end
      removed
    end
  end
end
