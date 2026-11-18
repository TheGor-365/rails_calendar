# Bearer token stays in the URL fragment (never sent via a GET, referrer or path).
# JavaScript posts it as a filtered body parameter, then only an encrypted cookie
# grants access to the safe public preview. A verified client must still claim via POST.
class ClientInvitationsController < ApplicationController
  before_action :require_pilot!
  after_action :private_headers!

  def landing
  end

  def preview
    raw = params[:invite_token]
    raw = raw.is_a?(String) ? raw : ""
    if SignupRateWindow.blocked?(
      purpose: "invite_preview_ip", identifier: request.remote_ip, seconds: 60, limit: 20
    )
      return head :too_many_requests
    end
    unless raw.match?(/\A[0-9a-f]{64}\z/)
      @state = :invalid
      return render :show, status: :not_found
    end
    invite = ClientRequestInvitation.find_by(token_digest: ClientRequestInvitation.digest_for(raw))
    unless invite
      @state = :invalid
      return render :show, status: :not_found
    end
    if invite.claimed_at.present? && (!client_signed_in? || invite.claimed_by_user_id != current_user.id)
      @state = :claimed
      return render :show, status: :gone
    end
    if invite.revoked_at.present? || (invite.claimed_at.nil? && invite.expires_at <= Time.current)
      @state = invite.revoked_at? ? :revoked : :expired
      return render :show, status: :gone
    end
    cookies.encrypted[:rc_e2_invitation_id] = {
      value: invite.id.to_s, expires: invite.expires_at,
      httponly: true, same_site: :lax, secure: Rails.env.production?
    }
    redirect_to client_invitation_preview_path, status: :see_other
  end

  def show
    @invitation = invited_from_cookie
    @state = @invitation&.state || :invalid
    if @state == :revoked || @state == :expired
      render :show, status: :gone
    elsif @state == :invalid
      render :show, status: :not_found
    end
  end

  def claim
    return redirect_to sign_in_path unless client_signed_in?
    @invitation = invited_from_cookie
    return head :not_found unless @invitation
    return head :unprocessable_entity unless params[:demo_consent] == "1"

    result = OwnerInvitations::Claim.call(invitation: @invitation, client: current_user)
    if result.is_a?(ProjectIntake)
      redirect_to edit_client_request_path(result), status: :see_other,
                  notice: I18n.t("e2.claimed_notice")
    else
      @state = result
      render :show, status: :conflict
    end
  end

  private

  def invited_from_cookie
    id = cookies.encrypted[:rc_e2_invitation_id].to_s
    return nil unless id.match?(/\A[1-9]\d*\z/)
    ClientRequestInvitation.includes(:workspace, :project_intake).find_by(id: id)
  end

  def require_pilot!
    head :not_found unless ClientRequestPilot.enabled?(request: request)
  end

  def private_headers!
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
