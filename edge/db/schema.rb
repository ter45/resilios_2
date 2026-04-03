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

ActiveRecord::Schema[8.1].define(version: 2026_04_03_225344) do
  create_table "categories", id: false, force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "id", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.string "restaurant_id", null: false
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["id"], name: "idx_categories_id", unique: true
    t.index ["restaurant_id"], name: "index_categories_on_restaurant_id"
  end

  create_table "order_items", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "id", null: false
    t.text "notes"
    t.string "order_id", null: false
    t.string "product_id", null: false
    t.string "product_name", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", default: "pending"
    t.decimal "subtotal", precision: 10, scale: 2
    t.datetime "synced_at"
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["id"], name: "idx_order_items_id", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", id: false, force: :cascade do |t|
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.string "id", null: false
    t.text "notes"
    t.datetime "opened_at", null: false
    t.string "restaurant_id", null: false
    t.string "status", default: "open"
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.string "sync_status", default: "pending"
    t.datetime "synced_at"
    t.string "table_id", null: false
    t.decimal "tax", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.string "waiter_name"
    t.index ["id"], name: "idx_orders_id", unique: true
    t.index ["restaurant_id"], name: "index_orders_on_restaurant_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["table_id"], name: "index_orders_on_table_id"
  end

  create_table "products", id: false, force: :cascade do |t|
    t.boolean "available", default: true
    t.string "category_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "id", null: false
    t.string "image_url"
    t.string "name", null: false
    t.integer "position", default: 0
    t.decimal "price", precision: 10, scale: 2, null: false
    t.string "restaurant_id", null: false
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["id"], name: "idx_products_id", unique: true
    t.index ["restaurant_id"], name: "index_products_on_restaurant_id"
  end

  create_table "restaurants", id: false, force: :cascade do |t|
    t.string "address"
    t.string "cloud_restaurant_id"
    t.datetime "created_at", null: false
    t.string "id", null: false
    t.datetime "last_sync_at"
    t.string "name", null: false
    t.string "node_token", null: false
    t.string "timezone", default: "America/Bogota"
    t.datetime "updated_at", null: false
    t.index ["id"], name: "idx_restaurants_id", unique: true
  end

  create_table "sync_operations", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "entity_id", null: false
    t.string "entity_type", null: false
    t.string "id", null: false
    t.text "last_error"
    t.string "operation_type", null: false
    t.text "payload", null: false
    t.string "restaurant_id", null: false
    t.integer "retry_count", default: 0
    t.string "status", default: "pending"
    t.datetime "synced_at"
    t.index ["created_at"], name: "index_sync_operations_on_created_at"
    t.index ["entity_id"], name: "index_sync_operations_on_entity_id"
    t.index ["id"], name: "idx_sync_operations_id", unique: true
    t.index ["restaurant_id", "status"], name: "index_sync_operations_on_restaurant_id_and_status"
    t.index ["status"], name: "index_sync_operations_on_status"
  end

  create_table "tables", id: false, force: :cascade do |t|
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.string "id", null: false
    t.string "label"
    t.string "number", null: false
    t.string "restaurant_id", null: false
    t.string "status", default: "available"
    t.datetime "updated_at", null: false
    t.index ["id"], name: "idx_tables_id", unique: true
    t.index ["restaurant_id", "number"], name: "index_tables_on_restaurant_id_and_number", unique: true
    t.index ["restaurant_id"], name: "index_tables_on_restaurant_id"
  end
end
