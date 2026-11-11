module WorkspaceMemory
  # Internal owner-only write/read facade. No guest/client routes exist yet.
  # Legacy intakes with null workspace_id are deliberately not returned.
  class ProjectIntakeScope
    def initialize(actor:, workspace:)
      @workspace = workspace
      @access = Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def create_draft!(client:, title:, project_type:, goal:)
      @access.assert_client!(client)
      @workspace.project_intakes.create!(
        client: client, title: title, project_type: project_type,
        goal: goal, status: "interviewing",
        # Existing schema currently requires this field for synthetic demos;
        # do not treat it as customer privacy consent.
        demo_consent_at: Time.current
      )
    end

    def find!(id:, client: nil)
      @access.assert_owner!
      @access.assert_client!(client) if client
      scope = @workspace.project_intakes
      scope = scope.where(client_id: client.id) if client
      scope.find(id)
    end

    def list(client: nil)
      @access.assert_owner!
      @access.assert_client!(client) if client
      scope = @workspace.project_intakes.order(created_at: :desc, id: :desc)
      client ? scope.where(client_id: client.id) : scope
    end
  end
end
