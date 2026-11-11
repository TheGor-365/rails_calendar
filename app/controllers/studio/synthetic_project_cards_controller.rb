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

    def workflow
      @workflow ||= SyntheticProjectCardWorkflow.new(
        actor: current_user, workspace: @workspace
      )
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
