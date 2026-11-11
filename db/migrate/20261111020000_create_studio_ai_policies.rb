class CreateStudioAiPolicies < ActiveRecord::Migration[8.1]
  def change
    # Scoped policy preferences; external provider execution remains hard-disabled.
    add_index :project_intakes, [:id, :workspace_id],
              unique: true, name: "idx_project_intakes_ai_tenant_reference"

    create_table :studio_ai_policies do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :project_intake_id
      t.string :mode, limit: 24, null: false, default: "off"
      t.jsonb :purposes, null: false, default: []
      t.integer :token_cap_per_call, null: false, default: 0
      t.integer :token_cap_per_day, null: false, default: 0
      t.decimal :usd_cap_per_call, precision: 12, scale: 4, null: false, default: 0
      t.decimal :usd_cap_per_month, precision: 12, scale: 4, null: false, default: 0
      t.boolean :external_consent, null: false, default: false
      t.timestamps
    end
    add_index :studio_ai_policies, :workspace_id,
              unique: true, where: "project_intake_id IS NULL",
              name: "idx_studio_ai_workspace_default"
    add_index :studio_ai_policies, [:workspace_id, :project_intake_id],
              unique: true, where: "project_intake_id IS NOT NULL",
              name: "idx_studio_ai_project_override"
    add_foreign_key :studio_ai_policies, :project_intakes,
                    column: [:project_intake_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_studio_ai_project_tenant"
    add_check_constraint :studio_ai_policies,
                         "mode IN ('off','offline','reviewed_provider')",
                         name: "chk_studio_ai_policy_mode"
    add_check_constraint :studio_ai_policies,
                         "jsonb_typeof(purposes) = 'array'",
                         name: "chk_studio_ai_policy_purposes_array"
    add_check_constraint :studio_ai_policies,
                         "token_cap_per_call >= 0 AND token_cap_per_day >= 0 AND usd_cap_per_call >= 0 AND usd_cap_per_month >= 0",
                         name: "chk_studio_ai_policy_caps"
  end
end
