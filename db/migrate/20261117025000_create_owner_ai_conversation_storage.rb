# RC055.1f C2.1a: isolated, owner-only durable conversations.
# No prompt ingestion, external provider calls, automatic publishing or retention jobs.
class CreateOwnerAiConversationStorage < ActiveRecord::Migration[8.1]
  def change
    create_table :owner_ai_conversations do |t|
      t.references :workspace, null: false, foreign_key: true, index: true
      t.string :title, null: false, limit: 100, default: "New AI conversation"
      t.string :state, null: false, limit: 16, default: "active"
      t.string :scope, null: false, limit: 32, default: "owner_general"
      t.datetime :retention_expires_at, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :owner_ai_conversations, [:workspace_id, :state, :updated_at],
              name: "idx_owner_ai_conversations_workspace_state"
    add_check_constraint :owner_ai_conversations, "state IN ('active', 'archived')",
                         name: "chk_owner_ai_conversation_state"
    add_check_constraint :owner_ai_conversations, "scope = 'owner_general'",
                         name: "chk_owner_ai_conversation_scope"
    add_check_constraint :owner_ai_conversations, "char_length(title) BETWEEN 1 AND 100",
                         name: "chk_owner_ai_conversation_title"

    create_table :owner_ai_messages do |t|
      t.references :owner_ai_conversation, null: false, foreign_key: true,
                   index: { name: "idx_owner_ai_messages_conversation" }
      t.references :ai_spend_entry, null: true, foreign_key: true, index: true
      t.bigint :parent_message_id
      t.integer :sequence, null: false
      t.uuid :request_id, null: false
      t.string :role, null: false, limit: 12
      t.string :state, null: false, limit: 16, default: "draft"
      t.text :body, null: false
      t.string :operation, limit: 40
      t.integer :approved_profile_version
      t.timestamps
    end

    add_index :owner_ai_messages, [:owner_ai_conversation_id, :sequence],
              unique: true, name: "idx_owner_ai_messages_unique_sequence"
    add_index :owner_ai_messages, [:owner_ai_conversation_id, :request_id],
              unique: true, name: "idx_owner_ai_messages_unique_request"
    add_index :owner_ai_messages, :parent_message_id, name: "idx_owner_ai_messages_parent"
    # The composite FK prevents an AI message from linking a parent in another
    # owner's conversation even if an unsafe direct SQL update bypasses validations.
    add_index :owner_ai_messages, [:id, :owner_ai_conversation_id], unique: true,
              name: "idx_owner_ai_messages_parent_scope_target"
    add_foreign_key :owner_ai_messages, :owner_ai_messages,
                    column: [:parent_message_id, :owner_ai_conversation_id],
                    primary_key: [:id, :owner_ai_conversation_id],
                    name: "fk_owner_ai_messages_parent_scoped"

    add_check_constraint :owner_ai_messages, "sequence > 0",
                         name: "chk_owner_ai_message_sequence"
    add_check_constraint :owner_ai_messages,
                         "(role = 'owner' AND state IN ('draft', 'settled') AND ai_spend_entry_id IS NULL AND char_length(body) BETWEEN 1 AND 1200) OR " \
                         "(role = 'assistant' AND state IN ('pending', 'settled', 'failed', 'uncertain') AND char_length(body) BETWEEN 1 AND 2800)",
                         name: "chk_owner_ai_message_role_state_size"
    add_check_constraint :owner_ai_messages,
                         "NOT (role = 'assistant' AND state = 'settled') OR ai_spend_entry_id IS NOT NULL",
                         name: "chk_owner_ai_message_settled_ledger"
    add_check_constraint :owner_ai_messages, "approved_profile_version IS NULL OR approved_profile_version > 0",
                         name: "chk_owner_ai_message_profile_version"
  end
end
