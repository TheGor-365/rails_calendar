module OwnerAi
  # Role-scoped read entrypoint. No controller or provider integration is
  # enabled in C2.1a; future routes must obtain records through this scope.
  class ConversationAccess
    def self.for_user(user)
      return OwnerAiConversation.none unless user&.role == "owner"
      workspace = user.owner_workspace
      return OwnerAiConversation.none unless workspace

      workspace.owner_ai_conversations
    end
  end
end
