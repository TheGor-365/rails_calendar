class RegistrationsController < ApplicationController
  layout "account"
  before_action :require_local_owner_bootstrap!
  before_action :limit_bootstrap_attempts!, only: :create

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params.merge(role: "owner"))

    # PostgreSQL transaction-scoped advisory lock closes the race between two
    # concurrent bootstrap requests without imposing a global single-owner
    # schema constraint on future multi-workspace accounts.
    saved = false
    already_taken = false
    User.transaction do
      User.connection.execute("SELECT pg_advisory_xact_lock(20261108, 32)")
      if User.where(role: "owner").exists?
        already_taken = true
      else
        saved = @user.save
      end
    end

    return head :not_found if already_taken

    if saved
      start_owner_session!(@user)
      redirect_to workspace_path, notice: I18n.t("flash.owner_created")
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    head :conflict
  end

  private

  def registration_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def require_local_owner_bootstrap!
    allowed_environment = Rails.env.development? || Rails.env.test?
    return if allowed_environment && request.local? &&
              ENV["RC_LOCAL_OWNER_SIGNUP"] == "true" && !User.where(role: "owner").exists?

    head :not_found
  end

  def limit_bootstrap_attempts!
    head :too_many_requests if AdminLoginWindow.throttled?(remote_ip: request.remote_ip)
  rescue ActiveRecord::ActiveRecordError
    head :service_unavailable
  end
end
