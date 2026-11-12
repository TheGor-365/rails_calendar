# Identity-only client landing. No owner tables/legacy intakes accessible.
class ClientHomeController < ApplicationController
  before_action :require_verified_client!

  def show
    @client_requests = ClientRequestPilot.enabled?(request: request) ? current_user.client_project_intakes.order(created_at: :desc, id: :desc).limit(25) : ProjectIntake.none
    @pilot_enabled = ClientRequestPilot.enabled?(request: request)
  end

  private

  def require_verified_client!
    return if client_signed_in?
    redirect_to sign_in_path, alert: "Client sign-in required"
  end
end
