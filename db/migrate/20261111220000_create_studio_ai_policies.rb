class CreateStudioAiPolicies < ActiveRecord::Migration[8.1]
  def change
    # Null intake = workspace default; nonnull = one project restriction.
    # Existing legacy intakes remain unassigned and are not backfilled.
    add_index :project_intakes, [:id, :workspace_id], unique: true,
              name: "idx_project_intakes_ai_tenant"

    create_table :studio_ai_policies do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :project_intake_id
      t.string :mode, limit: 24, null: false, default: "off"
      t.jsonb :allowed_purposes, null: false, default: []
      t.jsonb :allowed_data_classes, null: false, default: []
      t.integer :per_call_token_cap, null: false, default: 0
      t.integer :project_token_cap, null: false, default: 0
      t.integer :daily_token_cap, null: false, default: 0
      t.integer :monthly_token_cap, null: false, default: 0
      t.decimal :per_call_usd_cap, precision: 12, scale: 6, null: false, default: 0
      t.decimal :project_usd_cap, precision: 12, scale: 6, null: false, default: 0
      t.decimal :daily_usd_cap, precision: 12, scale: 6, null: false, default: 0
      t.decimal :monthly_usd_cap, precision: 12, scale: 6, null: false, default: 0
      t.timestamps
    end

    add_index :studio_ai_policies, :workspace_id,
              unique: true, where: "project_intake_id IS NULL",
              name: "idx_studio_ai_policy_one_workspace_default"
    add_index :studio_ai_policies, [:workspace_id, :project_intake_id],
              unique: true, where: "project_intake_id IS NOT NULL",
              name: "idx_studio_ai_policy_one_per_project"
    add_foreign_key :studio_ai_policies, :project_intakes,
                    column: [:project_intake_id, :workspace_id],
                    primary_key: [:id, :workspace_id],
                    name: "fk_studio_ai_policy_intake_tenant"
    add_check_constraint :studio_ai_policies,
                         "mode IN ('off', 'offline', 'reviewed_provider')",
                         name: "chk_studio_ai_policy_mode"
    add_check_constraint :studio_ai_policies,
                         "jsonb_typeof(allowed_purposes) = 'array' AND jsonb_typeof(allowed_data_classes) = 'array'",
                         name: "chk_studio_ai_policy_arrays"
    add_check_constraint :studio_ai_policies,
                         "per_call_token_cap >= 0 AND project_token_cap >= 0 AND daily_token_cap >= 0 AND monthly_token_cap >= 0",
                         name: "chk_studio_ai_policy_tokens"
    add_check_constraint :studio_ai_policies,
                         "per_call_usd_cap >= 0 AND project_usd_cap >= 0 AND daily_usd_cap >= 0 AND monthly_usd_cap >= 0",
                         name: "chk_studio_ai_policy_cost"
  end
end
