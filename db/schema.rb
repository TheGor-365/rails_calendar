# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_10_230000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admin_login_windows", force: :cascade do |t|
    t.string "client_digest", limit: 64, null: false
    t.bigint "window_start_epoch", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_digest", "window_start_epoch"], name: "idx_admin_login_windows_identity_and_window", unique: true
    t.index ["window_start_epoch"], name: "idx_admin_login_windows_cleanup"
  end

  create_table "client_consents", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "client_id", null: false
    t.bigint "recorded_by_id", null: false
    t.string "purpose", limit: 24, null: false
    t.boolean "granted", null: false
    t.string "source_ref", limit: 160, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "purpose", "created_at", "id"], name: "idx_client_consent_chronology"
    t.index ["recorded_by_id"], name: "index_client_consents_on_recorded_by_id"
    t.index ["workspace_id"], name: "index_client_consents_on_workspace_id"
  end

  create_table "client_facts", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "client_id", null: false
    t.bigint "recorded_by_id", null: false
    t.string "field_key", limit: 80, null: false
    t.integer "revision", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", limit: 20, null: false
    t.string "sensitivity", limit: 20, null: false
    t.string "purpose", limit: 24, null: false
    t.string "source_kind", limit: 24, null: false
    t.string "source_ref", limit: 160, null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "field_key", "revision"], name: "idx_client_fact_revision_unique", unique: true
    t.index ["recorded_by_id"], name: "index_client_facts_on_recorded_by_id"
    t.index ["workspace_id", "client_id", "field_key"], name: "idx_client_facts_scoped_lookup"
    t.index ["workspace_id"], name: "index_client_facts_on_workspace_id"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "display_name", limit: 120, null: false
    t.string "status", limit: 20, default: "prospect", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id", "workspace_id"], name: "idx_clients_id_workspace_unique", unique: true
    t.index ["workspace_id"], name: "index_clients_on_workspace_id"
  end

  create_table "consultation_reschedule_events", force: :cascade do |t|
    t.bigint "consultation_id", null: false
    t.datetime "old_start_time", null: false
    t.datetime "old_end_time", null: false
    t.datetime "new_start_time", null: false
    t.datetime "new_end_time", null: false
    t.string "actor_label", limit: 80, null: false
    t.text "reason", null: false
    t.datetime "created_at", null: false
    t.index ["consultation_id", "created_at", "id"], name: "idx_reschedule_history_by_consultation_and_time"
  end

  create_table "consultations", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "start_time"
    t.datetime "end_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
  end

  create_table "intake_ai_quotas", force: :cascade do |t|
    t.date "usage_day", null: false
    t.integer "call_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["usage_day"], name: "index_intake_ai_quotas_on_usage_day", unique: true
  end

  create_table "intake_answer_revisions", force: :cascade do |t|
    t.bigint "intake_answer_id", null: false
    t.integer "revision", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["intake_answer_id", "revision"], name: "idx_intake_answer_revisions_unique", unique: true
    t.index ["intake_answer_id"], name: "index_intake_answer_revisions_on_intake_answer_id"
  end

  create_table "intake_answers", force: :cascade do |t|
    t.bigint "project_intake_id", null: false
    t.string "question_key", limit: 64, null: false
    t.jsonb "selected_options", default: [], null: false
    t.string "other_text", limit: 300
    t.boolean "unsure", default: false, null: false
    t.text "comment"
    t.integer "revision", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "feature_priorities", default: {}, null: false
    t.index ["project_intake_id", "question_key"], name: "idx_intake_answers_unique_question", unique: true
    t.index ["project_intake_id"], name: "index_intake_answers_on_project_intake_id"
  end

  create_table "intake_messages", force: :cascade do |t|
    t.bigint "project_intake_id", null: false
    t.string "role", limit: 16, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_intake_id", "created_at", "id"], name: "idx_intake_conversation_order"
    t.index ["project_intake_id"], name: "index_intake_messages_on_project_intake_id"
  end

  create_table "intake_spec_versions", force: :cascade do |t|
    t.bigint "project_intake_id", null: false
    t.integer "version", null: false
    t.jsonb "document", default: {}, null: false
    t.string "source", limit: 16, null: false
    t.datetime "owner_approved_at"
    t.datetime "client_reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_intake_id", "version"], name: "idx_intake_spec_immutable_version", unique: true
    t.index ["project_intake_id"], name: "index_intake_spec_versions_on_project_intake_id"
  end

  create_table "project_intakes", force: :cascade do |t|
    t.string "title", limit: 120, null: false
    t.string "project_type", limit: 32, null: false
    t.text "goal", null: false
    t.string "status", limit: 32, default: "interviewing", null: false
    t.integer "ai_call_count", default: 0, null: false
    t.datetime "demo_consent_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id"
    t.bigint "client_id"
    t.index ["workspace_id"], name: "index_project_intakes_on_workspace_id"
    t.index ["id", "workspace_id", "client_id"], name: "idx_project_intakes_scoped_source_reference", unique: true
    t.index ["client_id", "workspace_id"], name: "idx_project_intakes_client_workspace"
  end

  create_table "project_sources", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "client_id", null: false
    t.bigint "project_intake_id", null: false
    t.bigint "recorded_by_id", null: false
    t.string "source_sha256", limit: 64, null: false
    t.integer "byte_size", null: false
    t.string "source_format", limit: 20, null: false
    t.string "parser_version", limit: 32, null: false
    t.string "state", limit: 32, default: "metadata_only", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_intake_id", "source_sha256", "parser_version"], name: "idx_project_sources_idempotency", unique: true
    t.index ["recorded_by_id"], name: "index_project_sources_on_recorded_by_id"
    t.index ["workspace_id", "client_id", "project_intake_id"], name: "idx_project_sources_tenant_scope"
    t.index ["workspace_id"], name: "index_project_sources_on_workspace_id"
  end

  create_table "project_milestones", force: :cascade do |t|
    t.bigint "project_intake_id", null: false
    t.bigint "intake_spec_version_id", null: false
    t.integer "position", null: false
    t.string "title", limit: 100, null: false
    t.text "description", null: false
    t.integer "suggested_work_days", null: false
    t.date "start_on", null: false
    t.date "end_on", null: false
    t.string "status", limit: 24, default: "proposed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["intake_spec_version_id"], name: "index_project_milestones_on_intake_spec_version_id"
    t.index ["project_intake_id", "position"], name: "idx_project_milestone_position", unique: true
    t.index ["project_intake_id"], name: "index_project_milestones_on_project_intake_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", limit: 64, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_user_sessions_on_expires_at"
    t.index ["token_digest"], name: "index_user_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", limit: 254, null: false
    t.string "password_digest", null: false
    t.string "role", limit: 20, default: "owner", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "idx_users_email_case_insensitive", unique: true
  end

  create_table "workspace_memberships", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "role", limit: 20, null: false
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_workspace_memberships_on_user_id"
    t.index ["workspace_id", "user_id"], name: "idx_workspace_member_unique", unique: true
    t.index ["workspace_id"], name: "index_workspace_memberships_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.bigint "owner_user_id", null: false
    t.string "name", limit: 120, null: false
    t.string "slug", limit: 64, null: false
    t.string "state", limit: 20, default: "internal", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_user_id"], name: "index_workspaces_on_owner_user_id"
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
  end

  add_foreign_key "client_consents", "clients", column: ["client_id", "workspace_id"], primary_key: ["id", "workspace_id"], name: "fk_client_consents_scoped_client"
  add_foreign_key "client_consents", "users", column: "recorded_by_id"
  add_foreign_key "client_consents", "workspaces"
  add_foreign_key "client_facts", "clients", column: ["client_id", "workspace_id"], primary_key: ["id", "workspace_id"], name: "fk_client_facts_scoped_client"
  add_foreign_key "client_facts", "users", column: "recorded_by_id"
  add_foreign_key "client_facts", "workspaces"
  add_foreign_key "clients", "workspaces"
  add_foreign_key "intake_answer_revisions", "intake_answers"
  add_foreign_key "intake_answers", "project_intakes"
  add_foreign_key "intake_messages", "project_intakes"
  add_foreign_key "intake_spec_versions", "project_intakes"
  add_foreign_key "project_intakes", "clients", column: ["client_id", "workspace_id"], primary_key: ["id", "workspace_id"], name: "fk_project_intakes_scoped_client"
  add_foreign_key "project_intakes", "workspaces"
  add_foreign_key "project_sources", "clients", column: ["client_id", "workspace_id"], primary_key: ["id", "workspace_id"], name: "fk_project_sources_client_tenant"
  add_foreign_key "project_sources", "project_intakes", column: ["project_intake_id", "workspace_id", "client_id"], primary_key: ["id", "workspace_id", "client_id"], name: "fk_project_sources_intake_tenant"
  add_foreign_key "project_sources", "users", column: "recorded_by_id"
  add_foreign_key "project_sources", "workspaces"
  add_foreign_key "project_milestones", "intake_spec_versions"
  add_foreign_key "project_milestones", "project_intakes"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "workspace_memberships", "users"
  add_foreign_key "workspace_memberships", "workspaces"
  add_foreign_key "workspaces", "users", column: "owner_user_id"
  add_check_constraint "project_intakes", "client_id IS NULL OR workspace_id IS NOT NULL", name: "chk_project_intakes_client_needs_workspace"
  add_check_constraint "project_sources", "state = 'metadata_only'", name: "chk_project_sources_no_release_before_privacy_gate"
  add_check_constraint "project_sources", "byte_size BETWEEN 1 AND 262144", name: "chk_project_sources_preview_size"
  add_check_constraint "project_sources", %q(source_sha256 ~ '^[0-9a-f]{64}$'), name: "chk_project_sources_sha256"
  add_check_constraint "project_sources", "source_format IN ('markdown', 'text', 'json')", name: "chk_project_sources_format"
end
