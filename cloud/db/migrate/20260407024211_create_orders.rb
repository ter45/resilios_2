class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders, id: false do |t|
      t.string   :id,            null: false
      t.string   :restaurant_id, null: false
      t.string   :edge_node_id
      t.string   :table_label,   null: false
      t.string   :status,        null: false, default: 'open'
      t.string   :waiter_name
      t.decimal  :subtotal,      precision: 10, scale: 2, default: 0
      t.decimal  :tax,           precision: 10, scale: 2, default: 0
      t.decimal  :total,         precision: 10, scale: 2, default: 0
      t.text     :notes
      t.string   :origin,        default: 'edge'
      t.boolean  :was_offline,   default: false
      t.datetime :opened_at,     null: false
      t.datetime :closed_at
      t.datetime :synced_at,     null: false
      t.timestamps
    end
    add_index :orders, :id,            unique: true
    add_index :orders, :restaurant_id
    add_index :orders, :edge_node_id
    add_index :orders, :status
    add_index :orders, :opened_at
    add_index :orders, [:restaurant_id, :opened_at]
    add_index :orders, [:restaurant_id, :was_offline]
  end
end
