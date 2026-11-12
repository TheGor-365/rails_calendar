# Gated public client identity. Never creates an owner or grants workspace membership.
class ClientRegistrationsController < ApplicationController
  layout "account"

  before_action :require_available!, except: :privacy
  before_action :redirect_authenticated!, except: :privacy

  GENERIC_NOTICE = "Если адрес доступен для регистрации, письмо с кодом будет отправлено.".freeze
  VERIFY_ERROR = "Код неверен, просрочен или число попыток исчерпано.".freeze

  def new
  end

  def create
    email = params.dig(:signup, :email).to_s.strip.downcase
    password = params.dig(:signup, :password).to_s
    confirmation = params.dig(:signup, :password_confirmation).to_s
    consent = params.dig(:signup, :consent).to_s

    unless valid_identity_input?(email, password, confirmation, consent)
      flash.now[:alert] = "Проверьте email, совпадение паролей от 12 до 72 байт и согласие на обработку данных."
      return render :new, status: :unprocessable_entity
    end

    return head :too_many_requests if blocked_start?(email)

    session[:pending_client_signup_email] = email

    if User.where("lower(email) = ?", email).exists?
      return redirect_to verify_client_registration_path, notice: GENERIC_NOTICE
    end

    result = issue_code(email: email, password: password, consent_at: Time.current)
    return head :service_unavailable if result == :delivery_failed

    redirect_to verify_client_registration_path, notice: GENERIC_NOTICE
  rescue ActiveRecord::RecordNotUnique
    # Same response under concurrent requests; a uniqueness race cannot grant an account.
    redirect_to verify_client_registration_path, notice: GENERIC_NOTICE
  end

  def verify_form
    return redirect_to client_registration_path unless pending_email?
    @masked_email = mask_email(session[:pending_client_signup_email])
  end

  def verify
    return redirect_to client_registration_path unless pending_email?

    code = params[:code].to_s.strip
    email = session[:pending_client_signup_email].to_s
    return head :too_many_requests if blocked_verify?(email)
    user = nil

    ClientSignupChallenge.transaction do
      challenge = ClientSignupChallenge.lock.find_by(email: email)
      if challenge && challenge.expires_at.future? && challenge.failed_attempts < ClientSignupChallenge::MAX_FAILURES
        if challenge.code_matches?(code)
          unless User.where("lower(email) = ?", email).exists?
            user = User.create!(
              email: challenge.email, password_digest: challenge.password_digest,
              role: "client", email_verified_at: Time.current, signup_consent_at: challenge.consent_at,
              signup_policy_version: challenge.policy_version
            )
            challenge.destroy!
          end
        else
          challenge.update!(failed_attempts: challenge.failed_attempts + 1)
        end
      end
    end

    if user
      session.delete(:pending_client_signup_email)
      start_account_session!(user)
      redirect_to client_home_path, notice: "Email подтверждён. Аккаунт создан."
    else
      flash.now[:alert] = VERIFY_ERROR
      verify_form
      render :verify_form, status: :unprocessable_entity unless performed?
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    flash.now[:alert] = VERIFY_ERROR
    verify_form
    render :verify_form, status: :unprocessable_entity unless performed?
  end

  def resend
    return redirect_to client_registration_path unless pending_email?
    email = session[:pending_client_signup_email].to_s
    return head :too_many_requests if blocked_start?(email)

    result = issue_code(email: email, password: nil, consent_at: nil, resend: true)
    return head :service_unavailable if result == :delivery_failed

    redirect_to verify_client_registration_path, notice: GENERIC_NOTICE
  end

  def privacy
  end

  private

  def require_available!
    head :not_found unless ClientSignupAvailability.enabled?
  end

  def redirect_authenticated!
    return redirect_to workspace_path if owner_signed_in?
    redirect_to client_home_path if client_signed_in?
  end

  def pending_email?
    session[:pending_client_signup_email].to_s.match?(/\A[^@\s]+@[^@\s]+\z/)
  end

  def valid_identity_input?(email, password, confirmation, consent)
    email.bytesize.between?(3, 254) &&
      URI::MailTo::EMAIL_REGEXP.match?(email) &&
      password.bytesize.between?(12, 72) &&
      password == confirmation && consent == "1"
  end

  def blocked_start?(email)
    SignupRateWindow.blocked?(purpose: "request_ip", identifier: request.remote_ip, seconds: 60, limit: 5) |
      SignupRateWindow.blocked?(purpose: "request_email", identifier: email, seconds: 3600, limit: 3)
  end

  def blocked_verify?(email)
    SignupRateWindow.blocked?(purpose: "verify_ip", identifier: request.remote_ip, seconds: 600, limit: 30) |
      SignupRateWindow.blocked?(purpose: "verify_email", identifier: email, seconds: 600, limit: 8)
  end

  # DB write is committed before mail delivery; failed delivery invalidates only this issue.
  # No secrets or email addresses are written to application logs.
  def issue_code(email:, password:, consent_at:, resend: false)
    issued_code = nil
    issued_digest = nil

    ClientSignupChallenge.transaction do
      challenge = ClientSignupChallenge.lock.find_by(email: email)
      now = Time.current

      if challenge
        # Cooldown is shared by first signup and explicit resend.
        next if challenge.sent_at > now - ClientSignupChallenge::RESEND_COOLDOWN

        new_window = challenge.window_started_at <= now - 1.hour
        next if !new_window && challenge.send_count >= ClientSignupChallenge::MAX_SENDS_PER_HOUR
        next if !new_window && challenge.failed_attempts >= ClientSignupChallenge::MAX_FAILURES

        issued_code = format("%06d", SecureRandom.random_number(1_000_000))
        issued_digest = ClientSignupChallenge.digest_for(email, issued_code)
        challenge.assign_attributes(
          code_digest: issued_digest, expires_at: now + ClientSignupChallenge::CODE_TTL,
          sent_at: now,
          send_count: new_window ? 1 : challenge.send_count + 1,
          window_started_at: new_window ? now : challenge.window_started_at,
          failed_attempts: new_window ? 0 : challenge.failed_attempts
        )
        # A resend may rotate a code, never replace a password or consent record.
        challenge.save!
      elsif !resend
        issued_code = format("%06d", SecureRandom.random_number(1_000_000))
        issued_digest = ClientSignupChallenge.digest_for(email, issued_code)
        ClientSignupChallenge.create!(
          email: email, password: password, consent_at: consent_at,
          code_digest: issued_digest, sent_at: now,
          policy_version: ClientSignupAvailability.policy_version,
          expires_at: now + ClientSignupChallenge::CODE_TTL,
          window_started_at: now
        )
      end
    end

    return :not_issued unless issued_code

    SignupMailer.verification_code(email, issued_code).deliver_now
    :sent
  rescue StandardError => error
    # External SMTP may fail after DB commit: invalidate the exact failed code
    # without deleting any newer challenge issued concurrently.
    if issued_digest
      ClientSignupChallenge.where(email: email, code_digest: issued_digest).delete_all
    end
    Rails.logger.error("Client signup mail delivery failed: #{error.class}")
    :delivery_failed
  end

  def mask_email(email)
    name, domain = email.to_s.split("@", 2)
    "#{name.to_s.first}***@#{domain}"
  end
end
