module Studio
  # Authenticated metadata ledger only; never exposes byte storage, direct
  # blob URLs, scan-bypass URLs or legacy unscoped intake records.
  class ProjectSourcesController < ApplicationController
    before_action :require_owner!
    before_action :set_scoped_intake
    before_action :no_store!

    def index
      sources = registry.list!(client: @client, intake: @intake)
      render json: { sources: sources.map { |source|
        { id: source.id, sha256: source.source_sha256,
          bytes: source.byte_size, format: source.source_format,
          state: source.state, downloadable: false }
      } }
    end

    def download
      # Lookup must still be tenant scoped. No object key or raw bytes exists.
      # Continue to deny even if metadata was registered successfully.
      registry.find!(client: @client, intake: @intake, id: params[:id])
      head :not_found
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def registry
      @registry ||= ProjectSourceRegistry.new(actor: current_user, workspace: @workspace)
    end

    def require_owner!
      redirect_to sign_in_path, alert: "Owner sign-in required" unless owner_signed_in?
    end

    def set_scoped_intake
      @workspace = Workspace.find(params[:workspace_id])
      @client = @workspace.clients.find(params[:client_id])
      @intake = WorkspaceMemory::ProjectIntakeScope.new(
        actor: current_user, workspace: @workspace
      ).find!(id: params[:project_intake_id], client: @client)
    rescue SecurityError, ActiveRecord::RecordNotFound
      head :not_found
    end

    def no_store!
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Content-Type-Options"] = "nosniff"
    end
  end
end
