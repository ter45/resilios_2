class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders, id: false do |t|
      t.string   :id,            null: false
      t.string   :restaurant_id, null: false
      t.string   :table_id,      null: false
      t.string   :status,        default: "open"
      t.string   :waiter_name
      t.decimal  :subtotal,      precision: 10, scale: 2, default: 0
      t.decimal  :tax,           precision: 10, scale: 2, default: 0
      t.decimal  :total,         precision: 10, scale: 2, default: 0
      t.text     :notes
      t.datetime :opened_at,     null: false
      t.datetime :closed_at
      t.datetime :synced_at
      t.string   :sync_status,   default: "pending"
      t.datetime :created_at,    null: false
      t.datetime :updated_at,   null: false
    end
    add_index :orders, :restaurant_id
    add_index :orders, :table_id
    add_index :orders, :status
    execute "CREATE UNIQUE INDEX idx_orders_id ON orders(id);"
  end
end
