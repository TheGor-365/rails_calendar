module Studio
  # JSON-only, owner-only invitation management. No client redemption route.
  class ProjectInvitationsController < ApplicationController
    before_action :require_owner!
    before_action :set_scoped_intake
    before_action :no_store!

    def index
      invitations = issuer.list!(client: @client, intake: @intake)
      render json: { invitations: invitations.map { |invitation|
        { id: invitation.id, status: invitation.status,
          role: invitation.role, expires_at: invitation.expires_at.iso8601 }
      } }
    end

    def create
      issued = issuer.issue!(
        client: @client, intake: @intake,
        recipient_email: params[:recipient_email]
      )
      # Plaintext bearer token exists only in this authorized no-store response.
      # It is NOT a working access link until verified client login ships.
      render json: { invitation_id: issued.invitation.id, token: issued.token,
                     status: "pending", redeemable: false },
             status: :created
    rescue ArgumentError, ActiveRecord::RecordInvalid
      render json: { error: "Invalid or duplicate invitation request" },
             status: :unprocessable_entity
    end

    def destroy
      issuer.revoke!(client: @client, intake: @intake, id: params[:id])
      head :no_content
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def issuer
      @issuer ||= ProjectInvitationIssuer.new(actor: current_user, workspace: @workspace)
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
