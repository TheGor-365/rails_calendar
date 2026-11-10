module Studio
  # Strict nonproduction-only onboarding. Mailbox possession proof alone does
  # not authenticate a person; a password session + one-time scoped invitation
  # acceptance and explicit policy consent are required for a LIMITED preview.
  class ClientOnboarding
    class Denied < StandardError; end

    def self.enabled?
      Rails.env.test? || (
        Rails.env.development? &&
        ENV["RC_STUDIO_CLIENT_ACCESS_DEMO"] == "true" &&
        ENV["RC_STUDIO_CLIENT_EMAIL_DEMO"] == "true"
      )
    end

    def register_and_accept!(token:, email:, password:, consent_policy:, consent_confirmation:)
      verify_demo!
      digest = ClientAccount.email_digest_for(email)
      validate_consent!(consent_policy, consent_confirmation)
      raise Denied, "Password outside permitted bounds" unless valid_password?(password)

      result = nil
      ActiveRecord::Base.transaction do
        invitation = locked_invitation!(token, digest)
        raise Denied, "Client mailbox has not been verified" unless email_proven?(invitation)
        raise Denied, "Client account already exists" if ClientAccount.exists?(email_digest: digest)

        account = ClientAccount.create!(email_digest: digest, password: password)
        grant = create_grant!(invitation, account)
        result = { account: account, grant: grant }
      end
      result
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      raise Denied, "Client onboarding rejected"
    end

    def accept_existing!(account:, token:, consent_policy:, consent_confirmation:)
      verify_demo!
      raise Denied, "Authenticated client session required" unless account.is_a?(ClientAccount) && account.persisted? && account.active?
      validate_consent!(consent_policy, consent_confirmation)
      grant = nil
      ActiveRecord::Base.transaction do
        invitation = locked_invitation!(token, account.email_digest)
        raise Denied, "Client mailbox has not been verified" unless email_proven?(invitation)
        grant = create_grant!(invitation, account)
      end
      grant
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      raise Denied, "Invitation already used or invalid"
    end

    private

    def verify_demo!
      raise SecurityError, "Nonproduction demo only" unless self.class.enabled?
    end

    def validate_consent!(policy, confirmation)
      unless policy == ClientProjectGrant::CONSENT_POLICY && confirmation == "yes"
        raise Denied, "Explicit consent is required"
      end
    end

    def valid_password?(password)
      password.is_a?(String) && password.bytesize.between?(12, 72)
    end

    def locked_invitation!(token, recipient_digest)
      raise Denied, "Invalid invitation" unless token.to_s.match?(/\A[0-9a-f]{64}\z/)
      digest = Digest::SHA256.hexdigest(token)
      invitation = ProjectInvitation.find_by(token_digest: digest)
      raise Denied, "Invalid invitation" unless invitation

      invitation.lock!
      unless invitation.status == "pending" && invitation.expires_at.future? &&
             ActiveSupport::SecurityUtils.secure_compare(invitation.recipient_digest, recipient_digest) &&
             invitation.workspace.owner_access?(invitation.issued_by) &&
             !ClientProjectGrant.exists?(project_invitation_id: invitation.id)
        raise Denied, "Invitation is unavailable"
      end
      invitation
    end

    def email_proven?(invitation)
      proof = invitation.project_invitation_email_proof
      proof&.verified? && proof.expires_at.future?
    end

    def create_grant!(invitation, account)
      now = Time.current
      ClientProjectGrant.create!(
        client_account: account, project_invitation: invitation,
        workspace: invitation.workspace, client: invitation.client,
        project_intake: invitation.project_intake, role: "reviewer",
        status: "active", consent_policy: ClientProjectGrant::CONSENT_POLICY,
        consented_at: now, accepted_at: now
      )
    end
  end
end
