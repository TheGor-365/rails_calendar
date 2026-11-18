# A request is unread only if it originates from a verified client's account
# and contains a client message not yet displayed to this owner.
#
# RC055.0 is an intentionally single-owner pilot: ProjectIntake does not yet
# carry an owner/workspace assignment. Multi-provider ACL must land separately
# BEFORE enabling multiple independent provider tenants in production.
class OwnerIntakeInbox
  class << self
    def unread_for(owner:)
      return ProjectIntake.none unless owner&.role == "owner"

      scoped = ProjectIntake.where(workspace_id: owner.owner_workspace&.id)
      if User.where(role: "owner").count == 1
        scoped = scoped.or(ProjectIntake.where(workspace_id: nil))
      end
      scoped.where.not(client_user_id: nil).where(<<~SQL.squish, owner_id: owner.id)
        EXISTS (
          SELECT 1
          FROM intake_messages AS unread_client_messages
          LEFT JOIN owner_intake_read_states AS owner_receipts
            ON owner_receipts.project_intake_id = project_intakes.id
           AND owner_receipts.owner_user_id = :owner_id
          WHERE unread_client_messages.project_intake_id = project_intakes.id
            AND unread_client_messages.role = 'client'
            AND (
              owner_receipts.last_seen_client_message_id IS NULL
              OR unread_client_messages.id > owner_receipts.last_seen_client_message_id
            )
        )
      SQL
    end

    # Mark exactly what the authorized owner was shown, never messages that
    # arrived after the response started, and never a legacy admin's session.
    def mark_seen!(owner:, intake:, displayed_messages:)
      raise ArgumentError, "owner account required" unless owner&.role == "owner"
      return false if intake.client_user_id.nil?
      return false if intake.workspace_id.present? && intake.workspace_id != owner.owner_workspace&.id
      return false if intake.workspace_id.nil? && User.where(role: "owner").count != 1

      latest = Array(displayed_messages)
        .select { |message| message.role == "client" && message.project_intake_id == intake.id }
        .max_by(&:id)
      return false unless latest
      return false unless IntakeMessage.where(id: latest.id, role: "client", project_intake_id: intake.id).exists?

      now = Time.current
      receipt = OwnerIntakeReadState.create_or_find_by!(owner_user: owner, project_intake: intake) do |state|
        state.last_seen_client_message = latest
        state.first_seen_at = now
        state.last_seen_at = now
      end

      # The row lock ensures that an older browser response cannot move the
      # read cursor backwards after a newer response has already been seen.
      receipt.with_lock do
        receipt.last_seen_client_message = latest if latest.id > receipt.last_seen_client_message_id
        receipt.last_seen_at = now
        receipt.save!
      end
      true
    end
  end
end
