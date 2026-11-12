class SignupMailer < ApplicationMailer
  def verification_code(email, code)
    @code = code
    mail(
      to: email,
      from: ENV.fetch("RC_SIGNUP_FROM", "no-reply@rails-calendar.invalid"),
      subject: "Rails Calendar — код подтверждения email"
    )
  end
end
