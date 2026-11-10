module Studio
  # This mailer is invoked solely in test or opted-in local development.
  # No recipient identity or message content is saved into project records.
  class InvitationEmailProofMailer < ApplicationMailer
    def verification_code(email:, code:)
      mail(
        to: email,
        subject: "Rails Calendar synthetic invitation verification",
        body: "Your synthetic test verification code: #{code}\nExpires in 10 minutes.\nNo client access is granted by this code."
      )
    end
  end
end
