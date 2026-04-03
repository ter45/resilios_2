class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items, id: false do |t|
      t.string   :id,           null: false
      t.string   :order_id,     null: false
      t.string   :product_id,   null: false
      t.string   :product_name, null: false
      t.decimal  :unit_price,   null: false, precision: 10, scale: 2
      t.integer  :quantity,     null: false, default: 1
      t.decimal  :subtotal,     precision: 10, scale: 2
      t.text     :notes
      t.string   :status,       default: "pending"
      t.datetime :synced_at
      t.datetime :created_at,   null: false
      t.datetime :updated_at,  null: false
    end
    add_index :order_items, :order_id
    add_index :order_items, :product_id
    execute "CREATE UNIQUE INDEX idx_order_items_id ON order_items(id);"
  end
end
