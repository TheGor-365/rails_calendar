class AccountSessionsController < ApplicationController
  before_action :limit_login_attempts!, only: :create

  def new
    redirect_to consultations_path if owner_signed_in?
  end

  def create
    email = params[:email].to_s.strip.downcase
    password = params[:password].to_s
    user = nil

    if email.bytesize <= 254 && password.bytesize <= 72 && password.present?
      user = User.authenticate_by(email: email, password: password)
    end

    if user&.role == "owner"
      start_owner_session!(user)
      redirect_to consultations_path, notice: "Signed in"
    else
      reset_session
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unauthorized
    end
  end

  def destroy
    end_owner_session!
    redirect_to root_path, notice: "Signed out"
  end

  private

  def limit_login_attempts!
    head :too_many_requests if AdminLoginWindow.throttled?(remote_ip: request.remote_ip)
  rescue ActiveRecord::ActiveRecordError
    head :service_unavailable
  end
end
