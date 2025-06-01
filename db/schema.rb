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

ActiveRecord::Schema[8.0].define(version: 2025_04_12_212949) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "access_token", limit: 1020
    t.string "refresh_token", limit: 1020
    t.string "email"
    t.string "name"
    t.string "first_name"
    t.string "last_name"
    t.datetime "expires_at"
    t.string "image_url"
    t.string "secondary_emails", default: [], array: true
  end

  create_table "accounts_models", id: false, force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "model_id", null: false
  end

  create_table "attachments", force: :cascade do |t|
    t.string "attachment_id"
    t.bigint "message_id", null: false
    t.string "filename"
    t.string "mime_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "size"
    t.string "content_id"
    t.integer "content_disposition", default: 0, null: false
    t.index ["message_id"], name: "index_attachments_on_message_id"
  end

  create_table "inboxes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.bigint "history_id"
    t.string "provider", null: false
    t.text "refresh_token"
    t.text "access_token"
    t.datetime "expires_at"
    t.string "microsoft_subscription_id"
    t.string "microsoft_client_state"
    t.datetime "last_sync_time"
    t.index ["account_id", "provider"], name: "index_inboxes_on_account_id_and_provider", unique: true
    t.index ["account_id"], name: "index_inboxes_on_account_id"
  end

  create_table "message_embeddings", force: :cascade do |t|
    t.vector "vector", limit: 2048
    t.bigint "message_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_message_embeddings_on_message_id", unique: true
  end

  create_table "message_embeddings_templates", id: false, force: :cascade do |t|
    t.bigint "message_embedding_id", null: false
    t.bigint "template_id", null: false
    t.index ["message_embedding_id", "template_id"], name: "index_message_embeddings_templates_unique", unique: true
    t.index ["message_embedding_id"], name: "index_message_embeddings_templates_on_message_embedding_id"
    t.index ["template_id"], name: "index_message_embeddings_templates_on_template_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "message_id"
    t.datetime "date"
    t.string "subject"
    t.string "from_email"
    t.string "to_email"
    t.bigint "topic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "internal_date"
    t.text "plaintext"
    t.text "html"
    t.string "snippet"
    t.string "from_name"
    t.string "to_name"
    t.text "provider_message_id"
    t.string "labels", default: [], array: true
    t.index ["message_id", "topic_id"], name: "index_messages_on_message_id_and_topic_id", unique: true
    t.index ["topic_id"], name: "index_messages_on_topic_id"
  end

  create_table "templates", force: :cascade do |t|
    t.text "input"
    t.text "output"
    t.vector "input_embedding", limit: 3072
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.index ["account_id"], name: "index_templates_on_account_id"
  end

  create_table "templates_topics", id: false, force: :cascade do |t|
    t.bigint "template_id", null: false
    t.bigint "topic_id", null: false
    t.index ["template_id"], name: "index_templates_topics_on_template_id"
    t.index ["topic_id"], name: "index_templates_topics_on_topic_id"
  end

  create_table "topics", force: :cascade do |t|
    t.string "thread_id"
    t.string "snippet"
    t.datetime "last_message"
    t.string "subject"
    t.string "from_email"
    t.string "to_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "inbox_id", null: false
    t.integer "message_count"
    t.bigint "template_id"
    t.string "generated_reply", default: ""
    t.integer "status", default: 0
    t.boolean "awaiting_customer"
    t.boolean "is_spam", default: false
    t.datetime "last_updated", default: -> { "CURRENT_TIMESTAMP" }
    t.string "from_name"
    t.string "to_name"
    t.index ["inbox_id"], name: "index_topics_on_inbox_id"
    t.index ["template_id"], name: "index_topics_on_template_id"
  end

  add_foreign_key "attachments", "messages"
  add_foreign_key "inboxes", "accounts"
  add_foreign_key "message_embeddings", "messages"
  add_foreign_key "messages", "topics"
  add_foreign_key "templates", "accounts"
  add_foreign_key "topics", "inboxes"
  add_foreign_key "topics", "templates"
end
