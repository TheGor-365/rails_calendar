module Studio
  # Owner-only, synthetic settings: UI never enables an external AI provider.
  class AiSettingsController < ApplicationController
    before_action :no_store!
    before_action :synthetic_only!
    before_action :require_owner!
    before_action :set_scoped_intake

    def show
      load_policies
    end

    # Explicit user action only. No background generation, file bytes or AI call.
    def preview
      raw_ids = params[:source_ids]
      unless raw_ids.nil? || raw_ids.is_a?(Array)
        raise ArgumentError, "Invalid source selection"
      end
      source_ids = Array(raw_ids)
      unless source_ids.length <= OfflineSourceSelector::MAX_SELECTED &&
             source_ids.all? { |id| id.is_a?(String) &&
               id.match?(/\A[1-9][0-9]{0,17}\z/) }
        raise ArgumentError, "Invalid source selection"
      end

      @proposal = OfflineAiDispatcher.new(
        actor: current_user, workspace: @workspace, intake: @intake
      ).call(purpose: params[:purpose], source_ids: source_ids.map(&:to_i))
      load_policies
      render :show
    rescue ArgumentError, OfflineSourceSelector::Denied,
           OfflineAiDispatcher::Denied, OfflineOutputContract::Denied
      load_policies
      @error = "Offline proposal rejected. Check active policies and source selection."
      render :show, status: :unprocessable_entity
    end

    def update
      target = params[:target].to_s
      mode = params[:mode].to_s
      raw_purposes = params[:purposes]
      unless %w[workspace project].include?(target) && %w[off offline].include?(mode) &&
             (raw_purposes.nil? || (raw_purposes.is_a?(Array) &&
               raw_purposes.all? { |x| x.is_a?(String) && AiPolicy::PURPOSES.include?(x) }))
        raise ArgumentError, "Invalid offline preference"
      end
      purposes = mode == "off" ? [] : Array(raw_purposes)
      raise ArgumentError, "Duplicate purpose" unless purposes.uniq == purposes

      scope_id = target == "workspace" ? nil : @intake.id
      policy = @workspace.studio_ai_policies.find_or_initialize_by(project_intake_id: scope_id)
      # Never permit these fields through the UI:
      # external_consent, provider names, API keys, token or USD caps.
      policy.audit_actor = current_user
      policy.assign_attributes(mode: mode, purposes: purposes)
      policy.save!
      redirect_to workspace_ai_settings_path(@workspace, @intake),
                  notice: "Offline-only preference saved. External AI is disabled."
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      load_policies
      @error = "Invalid offline-only setting. No provider call was made."
      render :show, status: :unprocessable_entity
    end

    private

    def load_policies
      @workspace_policy = @workspace.studio_ai_policies.find_by(project_intake_id: nil)
      @project_policy = @workspace.studio_ai_policies.find_by(project_intake_id: @intake.id)
      # Only safe revision metadata for an already-authorized owner.
      # Never expose digests, source content, credentials or actor emails.
      history = @workspace.studio_ai_policy_revisions
      @workspace_history = history.where(project_intake_id: nil)
        .order(revision: :desc).limit(15)
      @project_history = history.where(project_intake_id: @intake.id)
        .order(revision: :desc).limit(15)
      @synthetic_sources = @workspace.project_sources.where(
        client_id: @intake.client_id, project_intake_id: @intake.id,
        state: "metadata_only"
      ).order(:id).limit(OfflineSourceSelector::MAX_SELECTED)
    end

    def synthetic_only!
      return head :not_found if Rails.env.production?
      return if Rails.env.test? ||
                (Rails.env.development? && ENV["RC_STUDIO_AI_OFFLINE"] == "true")

      head :not_found
    end

    def require_owner!
      redirect_to sign_in_path, alert: "Owner sign-in required" unless owner_signed_in?
    end

    def set_scoped_intake
      @workspace = Workspace.find(params[:workspace_id])
      @intake = WorkspaceMemory::ProjectIntakeScope.new(
        actor: current_user, workspace: @workspace).find!(id: params[:id])
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
