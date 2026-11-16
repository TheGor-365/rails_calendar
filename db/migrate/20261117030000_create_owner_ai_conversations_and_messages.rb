class CreateOwnerAiConversationsAndMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :owner_ai_conversations do |t|
      t.references :workspace, null: false, foreign_key: true, index: false
      t.string :title, limit: 100, null: false, default: "New conversation"
      t.string :state, limit: 16, null: false, default: "active"
      t.string :scope, limit: 32, null: false, default: "owner_general"
      t.datetime :archived_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :owner_ai_conversations, [:workspace_id, :updated_at],
              name: "idx_owner_ai_conversations_recency"
    add_check_constraint :owner_ai_conversations,
                         "state IN ('active', 'archived')",
                         name: "chk_owner_ai_conversation_state"
    add_check_constraint :owner_ai_conversations,
                         "scope = 'owner_general'",
                         name: "chk_owner_ai_conversation_scope"
    add_check_constraint :owner_ai_conversations,
                         "(state = 'archived') = (archived_at IS NOT NULL)",
                         name: "chk_owner_ai_conversation_archive"

    create_table :owner_ai_messages do |t|
      t.references :owner_ai_conversation, null: false, foreign_key: true,
                   index: { name: "idx_owner_ai_messages_conversation" }
      t.references :parent_message, null: true, index: true
      t.references :ai_spend_entry, null: true, foreign_key: true
      t.integer :sequence, null: false
      t.uuid :request_id, null: false
      t.string :role, limit: 16, null: false
      t.string :state, limit: 16, null: false, default: "draft"
      t.string :operation, limit: 40
      t.integer :approved_profile_version
      t.text :body, null: false
      t.timestamps
    end

    add_foreign_key :owner_ai_messages, :owner_ai_messages,
                    column: :parent_message_id, name: "fk_owner_ai_message_parent"
    add_index :owner_ai_messages, [:owner_ai_conversation_id, :sequence],
              unique: true, name: "idx_owner_ai_message_sequence"
    add_index :owner_ai_messages, [:owner_ai_conversation_id, :request_id],
              unique: true, name: "idx_owner_ai_message_idempotency"
    add_check_constraint :owner_ai_messages,
                         "sequence > 0",
                         name: "chk_owner_ai_message_sequence_positive"
    add_check_constraint :owner_ai_messages,
                         "role IN ('owner', 'assistant')",
                         name: "chk_owner_ai_message_role"
    add_check_constraint :owner_ai_messages,
                         "state IN ('draft', 'pending', 'settled', 'failed', 'uncertain')",
                         name: "chk_owner_ai_message_state"
    add_check_constraint :owner_ai_messages,
                         "(role = 'owner' AND char_length(body) BETWEEN 1 AND 1200) OR " \
                         "(role = 'assistant' AND char_length(body) BETWEEN 1 AND 2800)",
                         name: "chk_owner_ai_message_length"
    add_check_constraint :owner_ai_messages,
                         "(role <> 'assistant' OR state <> 'settled' OR ai_spend_entry_id IS NOT NULL)",
                         name: "chk_owner_ai_settled_requires_spend"
    add_check_constraint :owner_ai_messages,
                         "(approved_profile_version IS NULL OR approved_profile_version > 0)",
                         name: "chk_owner_ai_profile_version_positive"
  end
end
