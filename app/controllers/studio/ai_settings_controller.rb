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
      source_ids = parsed_source_ids!
      @selected_source_ids = source_ids

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

    # Second explicit action after preview: persist a verified, unapproved
    # synthetic snapshot. Cannot accept raw output or cost from HTTP params.
    def record_run
      run = OfflineRunRecorder.new(
        actor: current_user, workspace: @workspace, intake: @intake
      ).record!(purpose: params[:purpose], source_ids: parsed_source_ids!)
      redirect_to workspace_ai_settings_path(@workspace, @intake),
                  notice: "Synthetic run version #{run.version} recorded for human review."
    rescue ArgumentError, OfflineRunRecorder::Denied, OfflineAiDispatcher::Denied,
           OfflineSourceSelector::Denied, AiBudgetAdmission::Denied,
           ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      load_policies
      @error = "Synthetic run rejected. Policies, output and metadata must be valid."
      render :show, status: :unprocessable_entity
    rescue SecurityError
      head :not_found
    end

    # One explicit immutable owner decision; never approval of client scope.
    def review_run
      OfflineRunReviewer.new(
        actor: current_user, workspace: @workspace, intake: @intake
      ).review!(run_id: params[:run_id], decision: params[:decision])
      redirect_to workspace_ai_settings_path(@workspace, @intake),
                  notice: "Synthetic-only review decision recorded. No client artifact was approved."
    rescue OfflineRunReviewer::Denied, ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotUnique
      load_policies
      @error = "Synthetic review rejected. Decision must be new and authorized."
      render :show, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound, SecurityError
      head :not_found
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

      @run_entries = @workspace.studio_offline_runs.where(
        client_id: @intake.client_id, project_intake_id: @intake.id
      ).includes(:review).order(version: :desc).limit(10).map do |run|
        begin
          payload = run.verified_payload!
          existing = run.review
          existing.verify! if existing
          { run: run, payload: payload, review: existing, verified: true }
        rescue SecurityError
          { run: run, verified: false }
        end
      end
    end

    def parsed_source_ids!
      raw = params[:source_ids]
      unless raw.nil? || raw.is_a?(Array)
        raise ArgumentError, "Invalid source selection"
      end
      values = Array(raw)
      unless values.length <= OfflineSourceSelector::MAX_SELECTED &&
             values.all? { |id| id.is_a?(String) &&
               id.match?(/\A[1-9][0-9]{0,17}\z/) }
        raise ArgumentError, "Invalid source selection"
      end
      values.map(&:to_i)
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
