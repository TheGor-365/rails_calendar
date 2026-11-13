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

ActiveRecord::Schema[8.1].define(version: 2026_11_13_123000) do
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

  add_foreign_key "intake_answer_revisions", "intake_answers"
  add_foreign_key "intake_answers", "project_intakes"
  add_foreign_key "intake_messages", "project_intakes"
  add_foreign_key "intake_spec_versions", "project_intakes"
  add_foreign_key "project_intakes", "users", column: "client_user_id"
  add_foreign_key "project_milestones", "intake_spec_versions"
  add_foreign_key "project_milestones", "project_intakes"
  add_foreign_key "user_sessions", "users"
end
