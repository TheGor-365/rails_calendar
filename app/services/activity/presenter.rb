module Activity
  # One allowlisted navigation map for calendar, library and activity history.
  # Never interpret an arbitrary database string as a URL.
  class Presenter
    ICONS = {
      "invitation_issued" => "send-check", "invitation_claimed" => "envelope-check",
      "invitation_submitted" => "envelope-check", "invitation_revoked" => "envelope-x",
      "intake_created" => "clipboard2-check", "requirements_saved" => "list-check",
      "ai_attempted" => "stars", "ai_settled" => "stars",
      "ai_uncertain" => "exclamation-circle", "ai_cancelled" => "x-circle",
      "conversation_created" => "chat-dots",
      "ai_reply_saved" => "chat-left-text"
    }.freeze

    def self.display(event)
      paths = Rails.application.routes.url_helpers
      path = case event.subject_type
      when "ClientRequestInvitation" then paths.owner_invitation_path(event.subject_id)
      when "ProjectIntake" then paths.project_intake_path(event.subject_id)
      when "IntakeRequirementSet"
        source = IntakeRequirementSet.joins(:project_intake)
          .where(project_intakes: { workspace_id: event.workspace_id })
          .find_by(id: event.subject_id)
        source ? paths.owner_requirements_path(source.project_intake_id) : paths.owner_artifacts_path
      when "AiSpendEntry"
        entry = AiSpendEntry.find_by(id: event.subject_id) if event.kind == "ai_settled"
        Activity::SourceLinks.ai_conversation_path(
          workspace_id: event.workspace_id, spend_entry: entry
        ) || paths.owner_ai_activity_path
      when "OwnerAiConversation"
        conversation = OwnerAiConversation.where(workspace_id: event.workspace_id)
          .find_by(id: event.subject_id)
        conversation && !conversation.removed? ?
          paths.owner_ai_conversation_path(conversation) : paths.owner_ai_conversations_path
      when "OwnerAiMessage"
        reply = OwnerAiMessage.joins(:owner_ai_conversation)
          .where(owner_ai_conversations: { workspace_id: event.workspace_id })
          .find_by(id: event.subject_id, role: "assistant", state: "settled")
        conversation = reply&.owner_ai_conversation
        if conversation && !conversation.removed? && reply.ai_spend_entry&.status == "settled"
          paths.owner_ai_conversation_path(conversation)
        else
          paths.owner_ai_conversations_path
        end
      else paths.owner_artifacts_path
      end
      { kind: event.kind.start_with?("ai_") ? :ai : event.kind.start_with?("invitation_") ? :invitation :
          event.kind == "requirements_saved" ? :requirements :
          event.kind == "conversation_created" ? :conversation : :request,
        icon: ICONS.fetch(event.kind, "activity"), title: event.title,
        created_at: event.occurred_at, path: path, status: event.kind,
        subject_type: event.subject_type, subject_id: event.subject_id }
    end
  end
end
