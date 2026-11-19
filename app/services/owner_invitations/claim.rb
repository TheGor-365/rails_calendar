module OwnerInvitations
  # Acquires the invitation row lock before binding the verified client.
  # Replaying by the same user returns the same intake; a different user is denied.
  class Claim
    def self.call(invitation:, client:)
      raise ArgumentError, "verified client required" unless client&.verified_client?

      result = nil
      invitation.with_lock do
        result = if invitation.claimed_at.present?
          invitation.claimed_by_user_id == client.id ? invitation.project_intake : :already_claimed
        elsif invitation.revoked_at.present?
          :revoked
        elsif invitation.expires_at <= Time.current
          :expired
        elsif !invitation.valid_published_versions?
          :services_changed
        else
          intake = client.client_project_intakes.create!(
            workspace: invitation.workspace,
            title: invitation.seed_title,
            project_type: invitation.seed_project_type,
            goal: invitation.seed_goal,
            demo_consent_at: Time.current,
            status: "interviewing"
          )
          invitation.published_versions.each do |version|
            intake.intake_service_selections.create!(service_offering_version: version)
          end
          intake.intake_brief_revisions.create!(
            version: 1, author_role: "owner",
            selections: invitation.brief_selections,
            decisions: invitation.brief_decisions,
            notes: invitation.brief_notes
          )
          invitation.update!(
            claimed_at: Time.current,
            claimed_by_user: client,
            project_intake: intake
          )
          intake
        end
      end
      result
    end
  end
end
