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

ActiveRecord::Schema[8.1].define(version: 2026_11_07_193000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "consultations", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "start_time"
    t.datetime "end_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
