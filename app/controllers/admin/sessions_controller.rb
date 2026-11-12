module Admin
  class SessionsController < ApplicationController
  layout "account"
    # Shared PostgreSQL counter counts all authentication attempts, including
    # successful ones, before reading any credentials. A database outage fails
    # closed rather than silently disabling throttling.
    before_action :enforce_admin_login_rate_limit!, only: :create

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

    private

    def enforce_admin_login_rate_limit!
      head :too_many_requests if AdminLoginWindow.throttled?(remote_ip: request.remote_ip)
    rescue ActiveRecord::ActiveRecordError => error
      Rails.logger.error("Administrator login limiter unavailable: #{error.class}")
      head :service_unavailable
    end
  end
end
