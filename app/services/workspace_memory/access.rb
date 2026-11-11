module WorkspaceMemory
  # Stage 1 is deliberately owner-only: future role grants require
  # a reviewed policy matrix, verified identities and controller tests.
  class Access
    def initialize(actor:, workspace:)
      @actor = actor
      @workspace = workspace
    end

    def assert_owner!
      unless @workspace.is_a?(Workspace) && @workspace.persisted? &&
             @workspace.owner_access?(@actor)
        raise SecurityError, "No access to this workspace"
      end

      true
    end

    def assert_client!(client)
      assert_owner!
      unless client.is_a?(Client) && client.persisted? &&
             client.workspace_id == @workspace.id
        raise SecurityError, "Client is outside this workspace"
      end

      true
    end
  end
end
