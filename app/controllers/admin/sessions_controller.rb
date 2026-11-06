module Admin
  class SessionsController < ApplicationController
    # Per-process protection for the demo. This is NOT a shared/distributed
    # production rate limiter: production must use a shared cache backend.
    LOGIN_RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new(size: 4.megabytes)

    # Count every login attempt (successful or failed) against the same IP.
    # Do not throttle public calendar routes.
    rate_limit to: 5, within: 1.minute, only: :create,
      store: LOGIN_RATE_LIMIT_STORE,
      with: -> { head :too_many_requests }

    def new
      redirect_to consultations_path if admin_signed_in?
    end

    def create
      username = params[:username].to_s
      password = params[:password].to_s

      # Cap submitted values to avoid unnecessary hashing of huge inputs.
      if username.bytesize <= 256 && password.bytesize <= 4096 &&
         valid_admin_credentials?(username, password)
        reset_session
        session[:admin_signed_in_at] = Time.current.to_i
        session[:admin_session_signature] = admin_session_signature
        redirect_to consultations_path, notice: "Administrator signed in"
      else
        reset_session
        flash.now[:alert] = "Invalid administrator credentials"
        render :new, status: :unauthorized
      end
    end

    def destroy
      reset_session
      redirect_to root_path, notice: "Administrator signed out"
    end
  end
end
