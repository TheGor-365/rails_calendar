module Studio
  class ClientSessionsController < ApplicationController
    before_action :demo_only!
    before_action :no_store!
    before_action :limit_attempts!, only: :create

    def create
      account = nil
      begin
        digest = ClientAccount.email_digest_for(params[:recipient_email])
        if params[:password].is_a?(String) && params[:password].bytesize.between?(1, 72)
          account = ClientAccount.find_by(email_digest: digest)
        end
      rescue ArgumentError
        account = nil
      end

      if account&.active? && account.authenticate(params[:password].to_s)
        start_studio_client_session!(account)
        render json: { authenticated: true, scope: "project_summary_only" }
      else
        reset_session
        render json: { authenticated: false }, status: :unauthorized
      end
    end

    def destroy
      end_studio_client_session!
      head :no_content
    end

    private

    def demo_only!
      head :not_found unless ClientOnboarding.enabled?
    end

    def no_store!
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Content-Type-Options"] = "nosniff"
    end

    def limit_attempts!
      head :too_many_requests if AdminLoginWindow.throttled?(remote_ip: request.remote_ip)
    rescue ActiveRecord::ActiveRecordError
      head :service_unavailable
    end
  end
end
