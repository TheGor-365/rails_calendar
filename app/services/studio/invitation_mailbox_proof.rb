require "digest"
require "openssl"
require "securerandom"

module Studio
  # Synthetic/local-only mailbox possession check. A bearer invitation token
  # by itself never verifies a person or grants access to any client data.
  class InvitationMailboxProof
    OTP_TTL = 10.minutes
    CODE = /\A[0-9]{6}\z/

    def self.enabled?
      Rails.env.test? || (Rails.env.development? && ENV["RC_STUDIO_CLIENT_EMAIL_DEMO"] == "true")
    end

    def request!(token:, email:)
      raise SecurityError, "Mailbox proof is not available" unless self.class.enabled?

      invitation = matching_invitation(token, email)
      return false unless invitation

      sent_code = nil
      ActiveRecord::Base.transaction do
        invitation.lock!
        next unless available_invitation?(invitation)
        next if invitation.project_invitation_email_proof

        sent_code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
        invitation.create_project_invitation_email_proof!(
          challenge_digest: challenge_digest(invitation.id, sent_code),
          expires_at: OTP_TTL.from_now
        )
      end
      return false unless sent_code

      InvitationEmailProofMailer.verification_code(email: normalize(email), code: sent_code).deliver_now
      true
    end

    def confirm!(token:, email:, code:)
      raise SecurityError, "Mailbox proof is not available" unless self.class.enabled?
      return false unless code.to_s.match?(CODE)

      invitation = matching_invitation(token, email)
      return false unless invitation

      verified = false
      ActiveRecord::Base.transaction do
        invitation.lock!
        next unless available_invitation?(invitation)
        proof = invitation.project_invitation_email_proof
        next unless proof && !proof.verified? && proof.expires_at.future? &&
                    proof.failed_attempts < ProjectInvitationEmailProof::MAX_ATTEMPTS
        expected = challenge_digest(invitation.id, code)
        if ActiveSupport::SecurityUtils.secure_compare(expected, proof.challenge_digest)
          proof.update!(verified_at: Time.current)
          verified = true
        else
          proof.update!(failed_attempts: proof.failed_attempts + 1)
        end
      end
      verified
    end

    private

    def matching_invitation(token, email)
      return unless token.to_s.match?(/\A[0-9a-f]{64}\z/)
      normalized = normalize(email)
      return unless normalized

      record = ProjectInvitation.find_by(token_digest: Digest::SHA256.hexdigest(token))
      return unless record && available_invitation?(record)

      expected = OpenSSL::HMAC.hexdigest(
        "SHA256", Rails.application.secret_key_base,
        "rc036-invite-recipient-v1:#{normalized}"
      )
      return unless ActiveSupport::SecurityUtils.secure_compare(expected, record.recipient_digest)

      record
    end

    def available_invitation?(invitation)
      invitation.status == "pending" && invitation.expires_at.future? &&
        invitation.workspace.owner_access?(invitation.issued_by)
    end

    def normalize(email)
      text = email.to_s.strip.downcase
      return unless text.bytesize.between?(3, 254) && text.match?(URI::MailTo::EMAIL_REGEXP)

      text
    end

    def challenge_digest(invitation_id, code)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base,
                            "rc036-invite-mailbox-proof-v1:#{invitation_id}:#{code}")
    end
  end
end
