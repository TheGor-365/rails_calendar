module Studio
  # Invitation-only client registration, disabled in production.
  # A mailbox OTP must be confirmed BEFORE this endpoint can create an account.
  class ClientAccountsController < ApplicationController
    before_action :demo_only!
    before_action :limit_attempts!
    before_action :no_store!

    def create
      result = ClientOnboarding.new.register_and_accept!(
        token: params[:invitation_token], email: params[:recipient_email],
        password: params[:password], consent_policy: params[:consent_policy],
        consent_confirmation: params[:consent_confirmation]
      )
      start_studio_client_session!(result.fetch(:account))
      render json: { grant_id: result.fetch(:grant).id, role: "reviewer",
                     consent_policy: result.fetch(:grant).consent_policy,
                     scope: "project_summary_only", access_granted: true }, status: :created
    rescue ClientOnboarding::Denied, ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      render json: { error: "Client registration or invitation rejected" }, status: :unprocessable_entity
    end

    private

    def demo_only!
      head :not_found unless ClientOnboarding.enabled?
    end

    def limit_attempts!
      head :too_many_requests if AdminLoginWindow.throttled?(remote_ip: request.remote_ip)
    rescue ActiveRecord::ActiveRecordError
      head :service_unavailable
    end

    def no_store!
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Content-Type-Options"] = "nosniff"
    end
  end
end
