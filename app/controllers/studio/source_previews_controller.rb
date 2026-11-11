module Studio
  # Private, owner-only synthetic file inspection. The bytes are intentionally
  # NOT persisted and never passed to a provider. This is not the final
  # upload/storage feature; private durable storage and malware scan are gates.
  class SourcePreviewsController < ApplicationController
    before_action :no_store!
    before_action :synthetic_only!
    before_action :require_owner!
    before_action :set_scoped_intake

    def new
      @plan = DocumentGenerationPlan.new.call(evidence: {})
    end

    def create
      upload = params[:source_file]
      raise ArgumentError, "Choose an MD, TXT or JSON file" unless upload.respond_to?(:read) &&
                                                                upload.respond_to?(:original_filename)

      @report = SourceInspector.new.call(
        filename: upload.original_filename,
        bytes: upload.read(SourceInspector::MAX_BYTES + 1)
      )
      @plan = DocumentGenerationPlan.new.call(evidence: { "source_inspected" => true })
      if params[:intent] == "download"
        markdown = DraftBriefRenderer.new.call(intake: @intake, report: @report, actor: current_user)
        return send_data markdown, type: "text/markdown; charset=utf-8",
                         filename: "project-#{@intake.id}-discovery-unapproved.md",
                         disposition: "attachment"
      end
      raise ArgumentError, "Unknown preview action" unless params[:intent].blank? || params[:intent] == "analyze"
      render :new
    rescue ArgumentError => error
      @error = error.message
      @plan = DocumentGenerationPlan.new.call(evidence: {})
      render :new, status: :unprocessable_entity
    end

    private

    # A preview still parses untrusted bytes in memory. Never expose that
    # processing path in production before a separately reviewed import gate.
    def synthetic_only!
      return head :not_found if Rails.env.production?
      return if Rails.env.test? ||
        (Rails.env.development? && ENV["RC_STUDIO_SYNTHETIC_STORAGE"] == "true")

      head :not_found
    end

    def require_owner!
      return if owner_signed_in?

      redirect_to sign_in_path, alert: "Owner sign-in required"
    end

    def set_scoped_intake
      @workspace = Workspace.find(params[:workspace_id])
      @intake = WorkspaceMemory::ProjectIntakeScope.new(
        actor: current_user, workspace: @workspace
      ).find!(id: params[:id])
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
