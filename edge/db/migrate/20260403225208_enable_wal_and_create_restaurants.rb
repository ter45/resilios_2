class EnableWalAndCreateRestaurants < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    execute "PRAGMA journal_mode=WAL;"
    execute "PRAGMA foreign_keys=ON;"

    create_table :restaurants, id: false do |t|
      t.string   :id,                   null: false
      t.string   :name,                 null: false
      t.string   :cloud_restaurant_id
      t.string   :node_token,           null: false
      t.string   :timezone,             default: "America/Bogota"
      t.string   :address
      t.datetime :last_sync_at
      t.datetime :created_at,           null: false
      t.datetime :updated_at,           null: false
    end

    execute "CREATE UNIQUE INDEX idx_restaurants_id ON restaurants(id);"
  end

  def down
    drop_table :restaurants
  end
end
