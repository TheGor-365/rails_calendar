module Studio
  # Nonproduction-only unauthenticated challenge initiation. There are no
  # permissions granted here and no response exposing valid invitation IDs.
  class InvitationEmailProofsController < ApplicationController
    before_action :deny_production!
    before_action :limit_attempts!
    before_action :private_response!

    def create
      InvitationMailboxProof.new.request!(
        token: params[:invitation_token], email: params[:recipient_email]
      )
      # Uniform response, including invalid/expired/revoked token or recipient.
      head :accepted
    rescue ActiveRecord::ActiveRecordError
      head :service_unavailable
    end

    def confirm
      valid = InvitationMailboxProof.new.confirm!(
        token: params[:invitation_token], email: params[:recipient_email],
        code: params[:verification_code]
      )
      if valid
        render json: { email_possession_confirmed: true, access_granted: false }
      else
        render json: { email_possession_confirmed: false, access_granted: false },
               status: :unprocessable_entity
      end
    rescue ActiveRecord::ActiveRecordError
      head :service_unavailable
    end

    private

    def deny_production!
      head :not_found unless InvitationMailboxProof.enabled?
    end

    def limit_attempts!
      head :too_many_requests if AdminLoginWindow.throttled?(remote_ip: request.remote_ip)
    rescue ActiveRecord::ActiveRecordError
      head :service_unavailable
    end

    def private_response!
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Content-Type-Options"] = "nosniff"
    end
  end
end
