module DomainOutbox
  # Shared fail-closed owner/workspace authority for READ-ONLY diagnostics
  # and a future explicitly reviewed supervised replay command.
  # This class does not deliver events, charge AI, or expose a replay route.
  class OperatorAccess
    # Deliberately smaller than the existing 1..100 read-only preview limit.
    REPLAY_LIMITS = [1, 5, 10, 25].freeze

    def self.workspace_for!(owner:)
      unless owner.is_a?(User) && owner.persisted? && owner.role == "owner"
        raise ArgumentError, "verified owner workspace required"
      end

      workspace = owner.owner_workspace
      unless workspace.is_a?(Workspace) && workspace.persisted? &&
          workspace.owner_user_id == owner.id
        raise ArgumentError, "verified owner workspace required"
      end

      workspace
    end

    # Validation only, never a signal to execute a replay.
    def self.replay_limit!(limit:)
      unless limit.is_a?(Integer) && REPLAY_LIMITS.include?(limit)
        raise ArgumentError, "supervised replay limit must be 1, 5, 10 or 25"
      end

      limit
    end
  end
end
