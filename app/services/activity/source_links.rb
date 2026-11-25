module Activity
  # Resolve private, canonical destinations without trusting provider output as
  # a URL. Used by calendar, activity history and the owner artifact library.
  class SourceLinks
    def self.ai_conversation_path(workspace_id:, spend_entry:)
      return unless workspace_id.is_a?(Integer) && workspace_id.positive?
      return unless spend_entry&.persisted? && spend_entry.status == "settled" &&
        spend_entry.operation == OwnerAi::ConversationResponder::VERSION
      return unless spend_entry.professional_profile&.workspace_id == workspace_id

      raw_id = spend_entry.result.is_a?(Hash) ? spend_entry.result["conversation_id"] : nil
      return unless raw_id.is_a?(Integer) && raw_id.positive?

      conversation = OwnerAiConversation.where(workspace_id: workspace_id)
        .where.not(state: "removed").find_by(id: raw_id)
      return unless conversation
      return unless conversation.owner_ai_messages
        .where(ai_spend_entry_id: spend_entry.id, role: "assistant", state: "settled").exists?

      Rails.application.routes.url_helpers.owner_ai_conversation_path(conversation)
    end
  end
end
