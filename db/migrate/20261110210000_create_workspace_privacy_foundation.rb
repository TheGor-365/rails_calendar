class CreateWorkspacePrivacyFoundation < ActiveRecord::Migration[8.1]
  def change
    # Stage 1: additive, unused by public routes. Never backfill or reassign
    # legacy intake records without a separately reviewed ownership plan.
    create_table :workspaces do |t|
      t.references :owner_user, null: false, foreign_key: { to_table: :users }
      t.string :name, limit: 120, null: false
      t.string :slug, limit: 64, null: false
      t.string :state, limit: 20, default: "internal", null: false
      t.timestamps
    end
    add_index :workspaces, :slug, unique: true

    create_table :workspace_memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, limit: 20, null: false
      t.string :status, limit: 20, default: "active", null: false
      t.timestamps
    end
    add_index :workspace_memberships, [:workspace_id, :user_id],
              unique: true, name: "idx_workspace_member_unique"

    create_table :clients do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :display_name, limit: 120, null: false
      t.string :status, limit: 20, default: "prospect", null: false
      t.timestamps
    end
    # A composite FK prevents app bugs from assigning another workspace's
    # client to a memory record, including when models are bypassed.
    add_index :clients, [:id, :workspace_id], unique: true,
              name: "idx_clients_id_workspace_unique"

    create_table :client_facts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :client_id, null: false
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.string :field_key, limit: 80, null: false
      t.integer :revision, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, limit: 20, null: false
      t.string :sensitivity, limit: 20, null: false
      t.string :purpose, limit: 24, null: false
      t.string :source_kind, limit: 24, null: false
      t.string :source_ref, limit: 160, null: false
      t.datetime :expires_at
      t.timestamps
    end
    add_index :client_facts, [:client_id, :field_key, :revision],
              unique: true, name: "idx_client_fact_revision_unique"
    add_index :client_facts, [:workspace_id, :client_id, :field_key],
              name: "idx_client_facts_scoped_lookup"
    add_foreign_key :client_facts, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_client_facts_scoped_client"

    # Append-only consent events: last event for a purpose is authoritative.
    # Recording consent does NOT enable AI processing or public access.
    create_table :client_consents do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :client_id, null: false
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.string :purpose, limit: 24, null: false
      t.boolean :granted, null: false
      t.string :source_ref, limit: 160, null: false
      t.timestamps
    end
    add_index :client_consents, [:client_id, :purpose, :created_at, :id],
              name: "idx_client_consent_chronology"
    add_foreign_key :client_consents, :clients,
                    column: [:client_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_client_consents_scoped_client"
  end
end
