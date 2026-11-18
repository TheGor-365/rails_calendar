class AddSafeRemovalToOwnerAiConversations < ActiveRecord::Migration[8.1]
  # Preserve message and billing evidence instead of destructive cascading deletes.
  def up
    remove_check_constraint :owner_ai_conversations, name: "chk_owner_ai_conversation_state"
    remove_check_constraint :owner_ai_conversations, name: "chk_owner_ai_conversation_archive"
    add_check_constraint :owner_ai_conversations,
      "state IN ('active', 'archived', 'removed')",
      name: "chk_owner_ai_conversation_state"
    add_check_constraint :owner_ai_conversations,
      "(state = 'active') = (archived_at IS NULL)",
      name: "chk_owner_ai_conversation_archive"
  end

  def down
    count = select_value("SELECT count(*) FROM owner_ai_conversations WHERE state = 'removed'").to_i
    raise ActiveRecord::IrreversibleMigration, "Restore #{count} removed threads first" if count.positive?

    remove_check_constraint :owner_ai_conversations, name: "chk_owner_ai_conversation_state"
    remove_check_constraint :owner_ai_conversations, name: "chk_owner_ai_conversation_archive"
    add_check_constraint :owner_ai_conversations, "state IN ('active', 'archived')",
                         name: "chk_owner_ai_conversation_state"
    add_check_constraint :owner_ai_conversations,
                         "(state = 'archived') = (archived_at IS NOT NULL)",
                         name: "chk_owner_ai_conversation_archive"
  end
end
