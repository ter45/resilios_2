class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products, id: false do |t|
      t.string   :id,            null: false
      t.string   :restaurant_id, null: false
      t.string   :category_id,   null: false
      t.string   :name,          null: false
      t.text     :description
      t.decimal  :price,         null: false, precision: 10, scale: 2
      t.boolean  :available,     default: true
      t.integer  :position,      default: 0
      t.string   :image_url
      t.datetime :synced_at
      t.datetime :created_at,    null: false
      t.datetime :updated_at,   null: false
    end
    add_index :products, :restaurant_id
    add_index :products, :category_id
    execute "CREATE UNIQUE INDEX idx_products_id ON products(id);"
  end
end
