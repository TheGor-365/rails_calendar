module Studio
  # RC-037: local synthetic owner settings only. No AI provider can be called.
  class AiSettingsController < ApplicationController
    before_action :no_store!
    before_action :synthetic_only!
    before_action :require_owner!
    before_action :set_scoped_intake

    def show
      load_policies
    end

    def update
      scope = params[:scope]
      raise ArgumentError, "Unsupported policy scope" unless %w[workspace project].include?(scope)

      input = params.require(:policy)
      mode = input[:mode]
      raise ArgumentError, "Unsupported policy mode" unless AiPolicy::MODES.include?(mode)

      intake_id = scope == "workspace" ? nil : @intake.id
      policy = @workspace.studio_ai_policies.find_or_initialize_by(project_intake_id: intake_id)
      policy.assign_attributes(
        mode: mode,
        allowed_purposes: input[:document_plan] == "1" ? ["document_plan"] : [],
        allowed_data_classes: input[:synthetic] == "1" ? ["synthetic"] : []
      )
      policy.save!
      redirect_to workspace_ai_settings_path(@workspace, @intake),
                  notice: "Nonproduction policy saved. External AI remains disabled."
    rescue ArgumentError, ActionController::ParameterMissing, ActiveRecord::RecordInvalid
      @error = "Policy was not saved. Verify the selected options."
      load_policies
      render :show, status: :unprocessable_entity
    end

    private

    def set_scoped_intake
      @workspace = Workspace.find(params[:workspace_id])
      @intake = WorkspaceMemory::ProjectIntakeScope.new(
        actor: current_user, workspace: @workspace
      ).find!(id: params[:id])
      # Legacy/unassigned intakes cannot be given project AI settings.
      head :not_found if @intake.client_id.nil?
    rescue SecurityError, ActiveRecord::RecordNotFound
      head :not_found
    end

    def synthetic_only!
      return head :not_found if Rails.env.production?
      return if Rails.env.test? ||
        (Rails.env.development? && ENV["RC_STUDIO_SYNTHETIC_STORAGE"] == "true")

      head :not_found
    end

    def require_owner!
      redirect_to sign_in_path, alert: "Owner sign-in required" unless owner_signed_in?
    end

    def load_policies
      @workspace_policy = @workspace.studio_ai_policies.find_by(project_intake_id: nil)
      @project_policy = @workspace.studio_ai_policies.find_by(project_intake_id: @intake.id)
    end

    def no_store!
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Content-Type-Options"] = "nosniff"
    end
  end
end
