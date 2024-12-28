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

ActiveRecord::Schema[8.0].define(version: 2024_12_28_042300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "access_token", limit: 1020
    t.string "refresh_token", limit: 1020
    t.string "provider"
    t.string "uid"
    t.string "email"
    t.string "name"
    t.string "first_name"
    t.string "last_name"
    t.datetime "expires_at"
    t.index ["provider", "uid"], name: "index_accounts_on_provider_and_uid", unique: true
  end

  create_table "accounts_models", id: false, force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "model_id", null: false
  end

  create_table "examples", force: :cascade do |t|
    t.text "input"
    t.text "output"
    t.vector "input_embedding", limit: 3072
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "model_id", null: false
    t.index ["model_id"], name: "index_examples_on_model_id"
  end

  create_table "inboxes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.index ["account_id"], name: "index_inboxes_on_account_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "message_id"
    t.datetime "date"
    t.string "subject"
    t.string "from"
    t.string "to"
    t.text "body"
    t.bigint "topic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id"], name: "index_messages_on_topic_id"
  end

  create_table "models", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "topics", force: :cascade do |t|
    t.string "thread_id"
    t.string "snippet"
    t.text "messages"
    t.datetime "date"
    t.string "subject"
    t.string "from"
    t.string "to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "inbox_id", null: false
    t.index ["inbox_id"], name: "index_topics_on_inbox_id"
  end

  add_foreign_key "examples", "models"
  add_foreign_key "inboxes", "accounts"
  add_foreign_key "messages", "topics"
  add_foreign_key "topics", "inboxes"
end
