class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items, id: false do |t|
      t.string   :id,           null: false
      t.string   :order_id,     null: false
      t.string   :product_name, null: false
      t.decimal  :unit_price,   null: false, precision: 10, scale: 2
      t.integer  :quantity,     null: false, default: 1
      t.decimal  :subtotal,     precision: 10, scale: 2
      t.text     :notes
      t.string   :status,       default: 'served'
      t.datetime :synced_at,    null: false
      t.timestamps
    end
    add_index :order_items, :id,       unique: true
    add_index :order_items, :order_id
  end
end
