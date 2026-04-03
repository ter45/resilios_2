class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, id: false do |t|
      t.string   :id,            null: false
      t.string   :restaurant_id, null: false
      t.string   :name,          null: false
      t.integer  :position,      default: 0
      t.boolean  :active,        default: true
      t.datetime :synced_at
      t.datetime :created_at,    null: false
      t.datetime :updated_at,   null: false
    end
    add_index :categories, :restaurant_id
    execute "CREATE UNIQUE INDEX idx_categories_id ON categories(id);"
  end
end
