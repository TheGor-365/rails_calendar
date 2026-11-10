module Studio
  # Stage 3 Slice C: synthetic owner-only quarantine/proxy. No client login,
  # direct ActiveStorage URLs, production uploads or public object links.
  class ProjectSourcesController < ApplicationController
    before_action :require_owner!
    before_action :set_scoped_intake
    before_action :no_store!

    def index
      sources = registry.list!(client: @client, intake: @intake).includes(:project_source_blob)
      render json: { sources: sources.map { |source|
        { id: source.id, sha256: source.source_sha256,
          bytes: source.byte_size, format: source.source_format,
          state: source.state,
          downloadable: PrivateSourceStorage.enabled? && source.project_source_blob&.downloadable? == true }
      } }
    end

    def create
      return head :not_found unless PrivateSourceStorage.enabled?

      upload = params[:source_file]
      unless upload.respond_to?(:read) && upload.respond_to?(:original_filename)
        raise ArgumentError, "Choose a synthetic MD, TXT or JSON file"
      end
      source = pipeline.stage!(client: @client, intake: @intake,
        filename: upload.original_filename,
        bytes: upload.read(SourceInspector::MAX_BYTES + 1), declared_mime: upload.content_type)
      render json: { source_id: source.id, state: "quarantined", downloadable: false }, status: :created
    rescue ArgumentError, ActiveRecord::RecordInvalid
      render json: { error: "Invalid or duplicate synthetic source" }, status: :unprocessable_entity
    rescue PrivateSourceStorage::Unavailable, ProjectSourcePipeline::Denied
      head :not_found
    end

    def download
      # Every access rechecks actor, membership, workspace, client and intake.
      result = pipeline.download!(client: @client, intake: @intake, source_id: params[:id])
      send_data result.fetch(:bytes), type: result.fetch(:mime),
        filename: "project-#{@intake.id}-source-#{params[:id]}#{result.fetch(:extension)}",
        disposition: "attachment"
    rescue ActiveRecord::RecordNotFound, SecurityError, ProjectSourcePipeline::Denied,
           PrivateSourceStorage::Unavailable
      head :not_found
    end

    private

    def pipeline
      @pipeline ||= ProjectSourcePipeline.new(actor: current_user, workspace: @workspace)
    end

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
      response.headers["Referrer-Policy"] = "no-referrer"
    end
  end
end
