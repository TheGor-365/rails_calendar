require "digest"
require "openssl"
require "securerandom"

module Studio
  # Issues owner-visible one-time tokens only. There is deliberately NO
  # client redemption path, email delivery, or permission grant in RC-036.
  # Recipient addresses are HMAC'd; neither email nor plaintext token is saved.
  class ProjectInvitationIssuer
    Issued = Struct.new(:invitation, :token, keyword_init: true)
    TOKEN_HOURS = 48
    HOURLY_LIMIT = 10

    def initialize(actor:, workspace:)
      @actor = actor
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def issue!(client:, intake:, recipient_email:)
      scope = checked_scope!(client: client, intake: intake)
      email = normalized_email!(recipient_email)
      digest = recipient_digest(email)
      raise ArgumentError, "Invitation issuance limit reached" if scope.where("created_at > ?", 1.hour.ago).count >= HOURLY_LIMIT
      if scope.where(recipient_digest: digest, status: "pending").where("expires_at > ?", Time.current).exists?
        raise ArgumentError, "An active invitation already exists"
      end

      token = SecureRandom.hex(32)
      invitation = scope.create!(
        issued_by: @actor, recipient_digest: digest,
        token_digest: Digest::SHA256.hexdigest(token),
        role: "reviewer", status: "pending",
        expires_at: TOKEN_HOURS.hours.from_now
      )
      Issued.new(invitation: invitation, token: token)
    end

    def list!(client:, intake:)
      checked_scope!(client: client, intake: intake).order(created_at: :desc, id: :desc)
    end

    def revoke!(client:, intake:, id:)
      invitation = checked_scope!(client: client, intake: intake).find(id)
      ProjectInvitation.transaction do
        invitation.lock!
        invitation.update!(status: "revoked") unless invitation.status == "revoked"
        grant = invitation.client_project_grant
        grant.update!(status: "revoked") if grant && grant.status != "revoked"
      end
      invitation
    end

    def accept!(*)
      # A link/token alone can never establish the identity of an invitee.
      # Requires a separately reviewed client login and identity binding.
      raise SecurityError, "Client identity verification is not implemented"
    end

    private

    def checked_scope!(client:, intake:)
      @access.assert_client!(client)
      raise SecurityError, "Invalid project intake" unless intake.is_a?(ProjectIntake) && intake.persisted?

      @workspace.project_intakes.where(client_id: client.id).find(intake.id)
      @workspace.project_invitations.where(client_id: client.id, project_intake_id: intake.id)
    end

    def normalized_email!(value)
      email = value.to_s.strip.downcase
      unless email.bytesize.between?(3, 254) && email.match?(URI::MailTo::EMAIL_REGEXP)
        raise ArgumentError, "A valid recipient email is required"
      end
      email
    end

    def recipient_digest(email)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base,
                            "rc036-invite-recipient-v1:#{email}")
    end
  end
end
