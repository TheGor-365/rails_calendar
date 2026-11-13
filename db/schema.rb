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

ActiveRecord::Schema[8.1].define(version: 2026_11_14_003000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_spend_entries", force: :cascade do |t|
    t.bigint "project_intake_id"
    t.bigint "professional_profile_id"
    t.string "operation", limit: 40, null: false
    t.string "model", limit: 64, null: false
    t.string "request_digest", limit: 64, null: false
    t.string "status", limit: 16, default: "reserved", null: false
    t.bigint "reserved_ticks", null: false
    t.bigint "charged_ticks"
    t.jsonb "result", default: {}, null: false
    t.jsonb "usage", default: {}, null: false
    t.string "provider_response_id", limit: 128
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "reserved_ticks >= 0 AND (charged_ticks IS NULL OR charged_ticks >= 0)", name: "chk_ai_spend_ticks_nonnegative"
    t.check_constraint "status IN ('reserved', 'settled', 'uncertain', 'cancelled')", name: "chk_ai_spend_status"
    t.check_constraint "(project_intake_id IS NOT NULL) <> (professional_profile_id IS NOT NULL)", name: "chk_ai_spend_exactly_one_subject"
    t.index ["professional_profile_id"], name: "index_ai_spend_entries_on_professional_profile_id"
    t.index ["project_intake_id", "created_at"], name: "index_ai_spend_entries_on_project_intake_id_and_created_at"
    t.index ["project_intake_id"], name: "index_ai_spend_entries_on_project_intake_id"
    t.index ["request_digest"], name: "index_ai_spend_entries_on_request_digest", unique: true
    t.index ["status", "created_at"], name: "index_ai_spend_entries_on_status_and_created_at"
  end

  create_table "workspaces", force: :cascade do |t|
    t.bigint "owner_user_id", null: false
    t.string "name", limit: 120, default: "My practice", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_user_id"], name: "index_workspaces_on_owner_user_id", unique: true
  end

  create_table "professional_profiles", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "onboarding_state", limit: 20, default: "draft", null: false
    t.string "headline", limit: 160
    t.text "private_summary"
    t.text "public_summary"
    t.jsonb "ai_suggestion", default: {}, null: false
    t.string "ai_input_digest", limit: 64
    t.datetime "ai_suggested_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_professional_profiles_on_workspace_id", unique: true
  end

  create_table "owner_interview_answers", force: :cascade do |t|
    t.bigint "professional_profile_id", null: false
    t.string "section_key", limit: 12, null: false
    t.jsonb "selected_options", default: [], null: false
    t.text "notes"
    t.boolean "unsure", default: false, null: false
    t.integer "revision", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["professional_profile_id", "section_key"], name: "idx_owner_answer_per_section", unique: true
    t.index ["professional_profile_id"], name: "index_owner_interview_answers_on_professional_profile_id"
  end

  create_table "owner_interview_answer_revisions", force: :cascade do |t|
    t.bigint "owner_interview_answer_id", null: false
    t.integer "revision", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_interview_answer_id", "revision"], name: "idx_owner_answer_revision_unique", unique: true
    t.index ["owner_interview_answer_id"], name: "index_owner_interview_answer_revisions_on_owner_interview_answer_id"
  end

  create_table "professional_context_snapshots", force: :cascade do |t|
    t.bigint "professional_profile_id", null: false
    t.integer "version", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "digest", limit: 64, null: false
    t.datetime "approved_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["professional_profile_id", "version"], name: "idx_owner_context_version", unique: true
    t.index ["professional_profile_id"], name: "index_professional_context_snapshots_on_professional_profile_id"
  end

  create_table "professional_capabilities", force: :cascade do |t|
    t.bigint "professional_profile_id", null: false
    t.integer "snapshot_version", null: false
    t.string "domain", limit: 80, null: false
    t.string "delivery_mode", limit: 20, null: false
    t.string "experience_claim", limit: 20, null: false
    t.string "evidence_status", limit: 24, default: "self_reported", null: false
    t.string "willingness", limit: 24, null: false
    t.string "privacy_scope", limit: 24, default: "private", null: false
    t.text "conditions"
    t.boolean "review_required", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["professional_profile_id", "snapshot_version", "domain"], name: "idx_owner_capability_snapshot", unique: true
    t.index ["professional_profile_id"], name: "index_professional_capabilities_on_professional_profile_id"
  end

  create_table "work_policies", force: :cascade do |t|
    t.bigint "professional_profile_id", null: false
    t.integer "snapshot_version", null: false
    t.jsonb "hard_no_go", default: [], null: false
    t.jsonb "work_preferences", default: [], null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["professional_profile_id", "snapshot_version"], name: "idx_owner_policy_snapshot", unique: true
    t.index ["professional_profile_id"], name: "index_work_policies_on_professional_profile_id"
  end

  create_table "admin_login_windows", force: :cascade do |t|
    t.string "client_digest", limit: 64, null: false
    t.bigint "window_start_epoch", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_digest", "window_start_epoch"], name: "idx_admin_login_windows_identity_and_window", unique: true
    t.index ["window_start_epoch"], name: "idx_admin_login_windows_cleanup"
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

  create_table "client_signup_challenges", force: :cascade do |t|
    t.string "email", limit: 254, null: false
    t.string "password_digest", null: false
    t.string "code_digest", limit: 64, null: false
    t.datetime "expires_at", null: false
    t.datetime "sent_at", null: false
    t.datetime "consent_at", null: false
    t.string "policy_version", limit: 80, null: false
    t.integer "failed_attempts", default: 0, null: false
    t.integer "send_count", default: 1, null: false
    t.datetime "window_started_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "idx_client_signup_email_unique", unique: true
    t.index ["expires_at"], name: "index_client_signup_challenges_on_expires_at"
  end

  create_table "signup_rate_windows", force: :cascade do |t|
    t.string "identity_digest", limit: 64, null: false
    t.string "purpose", limit: 32, null: false
    t.bigint "window_start_epoch", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purpose", "identity_digest", "window_start_epoch"], name: "idx_signup_rate_window_unique", unique: true
    t.index ["window_start_epoch"], name: "index_signup_rate_windows_on_window_start_epoch"
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
    t.bigint "client_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_user_id"], name: "index_project_intakes_on_client_user_id"
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
    t.datetime "email_verified_at"
    t.datetime "signup_consent_at"
    t.string "signup_policy_version", limit: 80
    t.index "lower((email)::text)", name: "idx_users_email_case_insensitive", unique: true
  end

  add_foreign_key "ai_spend_entries", "project_intakes"
  add_foreign_key "ai_spend_entries", "professional_profiles"
  add_foreign_key "owner_interview_answers", "professional_profiles"
  add_foreign_key "owner_interview_answer_revisions", "owner_interview_answers"
  add_foreign_key "professional_context_snapshots", "professional_profiles"
  add_foreign_key "professional_capabilities", "professional_profiles"
  add_foreign_key "professional_profiles", "workspaces"
  add_foreign_key "work_policies", "professional_profiles"
  add_foreign_key "workspaces", "users", column: "owner_user_id"
  add_foreign_key "intake_answer_revisions", "intake_answers"
  add_foreign_key "intake_answers", "project_intakes"
  add_foreign_key "intake_messages", "project_intakes"
  add_foreign_key "intake_spec_versions", "project_intakes"
  add_foreign_key "project_intakes", "users", column: "client_user_id"
  add_foreign_key "project_milestones", "intake_spec_versions"
  add_foreign_key "project_milestones", "project_intakes"
  add_foreign_key "user_sessions", "users"
end
