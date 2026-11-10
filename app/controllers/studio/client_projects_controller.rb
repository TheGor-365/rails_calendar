module Studio
  # Read-only *minimal* review summary, never sources, files, answers, facts,
  # owner notes, project memberships or unapproved documents.
  class ClientProjectsController < ApplicationController
    before_action :demo_only!
    before_action :no_store!
    before_action :require_client!

    def index
      grants = accessible_grants.includes(:project_intake).order(:id)
      render json: {
        projects: grants.map { |grant|
          { grant_id: grant.id, project_intake_id: grant.project_intake_id,
            title: grant.project_intake.title, role: grant.role,
            consent_policy: grant.consent_policy }
        }
      }
    end

    def show
      grant = accessible_grants.includes(:project_intake).find_by(id: params[:id])
      return head :not_found unless grant

      render json: {
        grant_id: grant.id, project_intake_id: grant.project_intake_id,
        title: grant.project_intake.title, role: grant.role,
        scope: "project_summary_only", raw_sources: false, downloadable: false
      }
    end

    def accept
      grant = ClientOnboarding.new.accept_existing!(
        account: current_studio_client, token: params[:invitation_token],
        consent_policy: params[:consent_policy],
        consent_confirmation: params[:consent_confirmation]
      )
      render json: { grant_id: grant.id, role: grant.role,
                     scope: "project_summary_only" }, status: :created
    rescue ClientOnboarding::Denied, ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      render json: { error: "Invitation cannot be accepted" }, status: :unprocessable_entity
    end

    private

    def accessible_grants
      ClientProjectGrant.accessible.where(studio_client_account_id: current_studio_client.id)
    end

    def demo_only!
      head :not_found unless ClientOnboarding.enabled?
    end

    def require_client!
      head :not_found unless current_studio_client
    end

    def no_store!
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Content-Type-Options"] = "nosniff"
    end
  end
end
