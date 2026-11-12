module Studio
  # RC-039 Slice C. HTTP contract for the synthetic Project Hub, not a user UI.
  # Route registration AND every action require test mode, with a separate
  # production hard-deny. No customer content or arbitrary task fields.
  class SyntheticProjectCardsController < ApplicationController
    before_action :test_only!
    before_action :require_owner!
    before_action :set_scoped_intake
    before_action :no_store!

    def index
      board = SyntheticProjectHubBoardPreview.new(
        actor: current_user, workspace: @workspace
      ).call(client: @client, intake: @intake, explicit_synthetic: true)

      render json: {
        board: board,
        cards: workflow.list(client: @client, intake: @intake, explicit_synthetic: true)
      }
    rescue SecurityError, SyntheticProjectHubBoardPreview::Denied,
           SyntheticProjectCardWorkflow::Denied
      head :not_found
    end

    # Human-readable, keyboard-operable preview for fictitious internal cards.
    # Separate from Slice C JSON endpoints to preserve their original contract.
    def show_preview
      load_preview_board!
    rescue SecurityError, SyntheticProjectHubBoardPreview::Denied,
           SyntheticProjectCardWorkflow::Denied, SyntheticProjectTaskGraph::Denied
      head :not_found
    end

    # These two HTML-only actions reuse Slice B's locked workflow; never
    # mutate columns directly and never accept arbitrary task/approval text.
    # RC-039 H: test-only engineering task operations. Document cards stay separate.
    def create_preview_task
      task_graph.create_task!(
        client: @client, intake: @intake, task_key: params[:task_key], explicit_synthetic: true
      )
      redirect_to "#{preview_path}#rc_hub_tasks", notice: "Fictional engineering task created. No work approved."
    rescue SyntheticProjectTaskGraph::Denied, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      render_preview_problem("Fictional task creation rejected. Review the current task board.", :unprocessable_entity)
    rescue SecurityError, ActiveRecord::RecordNotFound
      head :not_found
    end

    def transition_preview_task
      task_lifecycle.transition!(
        client: @client, intake: @intake,
        task_id: positive_integer!(params[:task_id]),
        expected_state: params[:expected_state], expected_version: exact_version!,
        to_state: params[:to_state], explicit_synthetic: true
      )
      redirect_to "#{preview_path}#rc_hub_tasks",
                  notice: "Fictional task state recorded. Client acceptance is still absent."
    rescue SyntheticProjectTaskLifecycle::Conflict, ActiveRecord::StaleObjectError
      render_preview_problem("Engineering task changed. Review its current state and version before retrying.", :conflict)
    rescue ArgumentError, SyntheticProjectTaskLifecycle::Denied, ActiveRecord::RecordInvalid
      render_preview_problem("Fictional task transition denied; prerequisites or permitted states need review.", :unprocessable_entity)
    rescue SecurityError, ActiveRecord::RecordNotFound
      head :not_found
    end

    def reprioritize_preview_task
      task_lifecycle.reprioritize!(
        client: @client, intake: @intake,
        task_id: positive_integer!(params[:task_id]),
        expected_state: params[:expected_state], expected_version: exact_version!,
        priority: positive_integer!(params[:priority]), explicit_synthetic: true
      )
      redirect_to "#{preview_path}#rc_hub_tasks",
                  notice: "Fictional task priority recorded; dependencies still take precedence."
    rescue SyntheticProjectTaskLifecycle::Conflict, ActiveRecord::StaleObjectError
      render_preview_problem("Engineering task changed. Review its current state and version before retrying.", :conflict)
    rescue ArgumentError, SyntheticProjectTaskLifecycle::Denied, ActiveRecord::RecordInvalid
      render_preview_problem("Fictional task priority rejected. No change recorded.", :unprocessable_entity)
    rescue SecurityError, ActiveRecord::RecordNotFound
      head :not_found
    end

    def add_preview_dependency
      task_graph.add_dependency!(
        client: @client, intake: @intake,
        dependent_task_id: positive_integer!(params[:dependent_task_id]),
        prerequisite_task_id: positive_integer!(params[:prerequisite_task_id]),
        explicit_synthetic: true
      )
      redirect_to "#{preview_path}#rc_hub_tasks",
                  notice: "Fictional prerequisite recorded. No schedule or task approved."
    rescue ArgumentError, SyntheticProjectTaskGraph::Denied, ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotUnique
      render_preview_problem("Fictional dependency rejected. Cycles, late edges and cross-project links are forbidden.", :unprocessable_entity)
    rescue SecurityError, ActiveRecord::RecordNotFound
      head :not_found
    end

    def create_preview_card
      workflow.create!(
        client: @client, intake: @intake, artifact_key: params[:artifact_key],
        explicit_synthetic: true
      )
      redirect_to preview_path, notice: "Fictional card recorded. No scope approved."
    rescue SyntheticProjectCardWorkflow::Denied, ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotUnique
      render_preview_problem("That fictional card cannot be created. Review the current board.", :unprocessable_entity)
    rescue ActiveRecord::RecordNotFound, SecurityError
      head :not_found
    end

    def transition_preview_card
      workflow.transition!(
        client: @client, intake: @intake, card_id: params[:card_id],
        expected_state: params[:expected_state],
        expected_version: expected_version!, to_state: params[:to_state],
        explicit_synthetic: true
      )
      redirect_to preview_path, notice: "Fictional card state recorded. No approval granted."
    rescue SyntheticProjectCardWorkflow::Conflict, ActiveRecord::StaleObjectError
      render_preview_problem("Card changed since this page was opened. Review its current state before trying again.", :conflict)
    rescue ArgumentError, SyntheticProjectCardWorkflow::Denied,
           ActiveRecord::RecordInvalid
      render_preview_problem("That fictional state transition is not permitted. No change was saved.", :unprocessable_entity)
    rescue ActiveRecord::RecordNotFound, SecurityError
      head :not_found
    end

    def create
      card = workflow.create!(
        client: @client, intake: @intake,
        artifact_key: params[:artifact_key], explicit_synthetic: true
      )
      render json: { card: card }, status: :created
    rescue SyntheticProjectCardWorkflow::Denied, ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotUnique
      render json: { error: "Invalid synthetic card request" }, status: :unprocessable_entity
    rescue SecurityError, ActiveRecord::RecordNotFound
      head :not_found
    end

    def update
      card = workflow.transition!(
        client: @client, intake: @intake,
        card_id: params[:card_id],
        expected_state: params[:expected_state],
        expected_version: expected_version!,
        to_state: params[:to_state],
        explicit_synthetic: true
      )
      render json: { card: card }
    rescue SyntheticProjectCardWorkflow::Conflict, ActiveRecord::StaleObjectError
      render json: { error: "Synthetic card version conflict" }, status: :conflict
    rescue ArgumentError, SyntheticProjectCardWorkflow::Denied,
           ActiveRecord::RecordInvalid
      render json: { error: "Invalid synthetic transition" }, status: :unprocessable_entity
    rescue SecurityError, ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    # Read the same owner-scoped board on both successful GET and failed POST/
    # PATCH; a 409 response must never echo stale form fields or raw inputs.
    def load_preview_board!
      @board = SyntheticProjectHubBoardPreview.new(
        actor: current_user, workspace: @workspace
      ).call(client: @client, intake: @intake, explicit_synthetic: true)
      @saved_cards_by_key = workflow.list(
        client: @client, intake: @intake, explicit_synthetic: true
      ).index_by { |row| row.fetch("artifact_key") }
      @task_preview = task_graph.snapshot(
        client: @client, intake: @intake, explicit_synthetic: true
      )
    end

    def render_preview_problem(message, status)
      load_preview_board!
      @error = message
      render :show_preview, status: status
    rescue SecurityError, SyntheticProjectHubBoardPreview::Denied,
           SyntheticProjectCardWorkflow::Denied,
           SyntheticProjectTaskGraph::Denied, ActiveRecord::RecordNotFound
      head :not_found
    end

    def preview_path
      rc039_synthetic_project_hub_preview_path(@workspace, @client, @intake)
    end

    def workflow
      @workflow ||= SyntheticProjectCardWorkflow.new(
        actor: current_user, workspace: @workspace
      )
    end

    def task_graph
      @task_graph ||= SyntheticProjectTaskGraph.new(
        actor: current_user, workspace: @workspace
      )
    end

    def task_lifecycle
      @task_lifecycle ||= SyntheticProjectTaskLifecycle.new(
        actor: current_user, workspace: @workspace
      )
    end

    def positive_integer!(value)
      raw = value.to_s
      raise ArgumentError, "Positive integer required" unless raw.match?(/\A[1-9][0-9]{0,8}\z/)
      raw.to_i
    end

    def exact_version!
      raw = params[:expected_version]
      raise ArgumentError, "Exact version required" unless raw.is_a?(String) &&
        raw.match?(/\A(?:0|[1-9][0-9]{0,8})\z/)
      raw.to_i
    end

    def expected_version!
      raw = params[:expected_version]
      unless raw.is_a?(String) && raw.match?(/\A(?:0|[1-9][0-9]{0,8})\z/)
        raise ArgumentError, "Exact synthetic card version required"
      end
      raw.to_i
    end

    def test_only!
      head :not_found unless Rails.env.test? && !Rails.env.production?
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
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Content-Type-Options"] = "nosniff"
    end
  end
end
