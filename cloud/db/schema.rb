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

ActiveRecord::Schema[8.1].define(version: 2026_04_07_024221) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"

  create_table "accounts", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "id", null: false
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "plan", default: "trial"
    t.string "status", default: "active"
    t.string "stripe_customer_id"
    t.string "timezone", default: "America/Bogota"
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_accounts_on_email", unique: true
    t.index ["id"], name: "index_accounts_on_id", unique: true
    t.index ["status"], name: "index_accounts_on_status"
  end

  create_table "edge_nodes", id: false, force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "id", null: false
    t.string "ip_address"
    t.datetime "last_seen_at"
    t.datetime "last_sync_at"
    t.string "node_token_hash", null: false
    t.integer "pending_operations", default: 0
    t.string "restaurant_id", null: false
    t.string "sync_status", default: "unknown"
    t.jsonb "telemetry", default: {}
    t.datetime "updated_at", null: false
    t.string "version"
    t.index ["id"], name: "index_edge_nodes_on_id", unique: true
    t.index ["last_seen_at"], name: "index_edge_nodes_on_last_seen_at"
    t.index ["node_token_hash"], name: "index_edge_nodes_on_node_token_hash", unique: true
    t.index ["restaurant_id"], name: "index_edge_nodes_on_restaurant_id"
    t.index ["sync_status"], name: "index_edge_nodes_on_sync_status"
  end

  create_table "order_items", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "id", null: false
    t.text "notes"
    t.string "order_id", null: false
    t.string "product_name", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", default: "served"
    t.decimal "subtotal", precision: 10, scale: 2
    t.datetime "synced_at", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_order_items_on_id", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", id: false, force: :cascade do |t|
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.string "edge_node_id"
    t.string "id", null: false
    t.text "notes"
    t.datetime "opened_at", null: false
    t.string "origin", default: "edge"
    t.string "restaurant_id", null: false
    t.string "status", default: "open", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.datetime "synced_at", null: false
    t.string "table_label", null: false
    t.decimal "tax", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.string "waiter_name"
    t.boolean "was_offline", default: false
    t.index ["edge_node_id"], name: "index_orders_on_edge_node_id"
    t.index ["id"], name: "index_orders_on_id", unique: true
    t.index ["opened_at"], name: "index_orders_on_opened_at"
    t.index ["restaurant_id", "opened_at"], name: "index_orders_on_restaurant_id_and_opened_at"
    t.index ["restaurant_id", "was_offline"], name: "index_orders_on_restaurant_id_and_was_offline"
    t.index ["restaurant_id"], name: "index_orders_on_restaurant_id"
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "restaurants", id: false, force: :cascade do |t|
    t.string "account_id", null: false
    t.boolean "active", default: true
    t.string "address"
    t.datetime "created_at", null: false
    t.string "currency", default: "COP"
    t.string "id", null: false
    t.string "name", null: false
    t.string "phone"
    t.jsonb "settings", default: {}
    t.string "timezone", default: "America/Bogota"
    t.datetime "updated_at", null: false
    t.index ["account_id", "active"], name: "index_restaurants_on_account_id_and_active"
    t.index ["account_id"], name: "index_restaurants_on_account_id"
    t.index ["id"], name: "index_restaurants_on_id", unique: true
  end

  create_table "subscriptions", id: false, force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.string "id", null: false
    t.integer "orders_per_month_limit", default: 500
    t.string "plan", null: false
    t.string "status", null: false
    t.string "stripe_subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_subscriptions_on_account_id"
    t.index ["id"], name: "index_subscriptions_on_id", unique: true
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
  end

  create_table "sync_logs", id: false, force: :cascade do |t|
    t.jsonb "conflict_detail"
    t.string "edge_node_id", null: false
    t.string "entity_id", null: false
    t.string "entity_type", null: false
    t.string "id", null: false
    t.string "operation_id", null: false
    t.string "operation_type", null: false
    t.jsonb "payload", null: false
    t.datetime "processed_at", null: false
    t.integer "processing_ms"
    t.datetime "received_at", null: false
    t.string "restaurant_id", null: false
    t.string "result", null: false
    t.index ["edge_node_id", "received_at"], name: "index_sync_logs_on_edge_node_id_and_received_at"
    t.index ["edge_node_id"], name: "index_sync_logs_on_edge_node_id"
    t.index ["entity_id"], name: "index_sync_logs_on_entity_id"
    t.index ["id"], name: "index_sync_logs_on_id", unique: true
    t.index ["operation_id"], name: "index_sync_logs_on_operation_id", unique: true
    t.index ["result"], name: "index_sync_logs_on_result"
  end
end
