class CreateTables < ActiveRecord::Migration[8.0]
  def change
    create_table :tables, id: false do |t|
      t.string   :id,            null: false
      t.string   :restaurant_id, null: false
      t.string   :number,        null: false
      t.string   :label
      t.string   :status,        default: "available"
      t.integer  :capacity
      t.datetime :created_at,    null: false
      t.datetime :updated_at,   null: false
    end
    add_index :tables, :restaurant_id
    add_index :tables, [:restaurant_id, :number], unique: true
    execute "CREATE UNIQUE INDEX idx_tables_id ON tables(id);"
  end
end
