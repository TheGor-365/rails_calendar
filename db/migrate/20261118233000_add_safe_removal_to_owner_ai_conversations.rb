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
    # The historical constraint would reject tombstones. Explicitly block
    # irreversible data loss; operators must restore removed rows first.
    raise ActiveRecord::IrreversibleMigration, "Restore all removed conversations before a rollback"
  end
end
