class CreateRestaurants < ActiveRecord::Migration[8.0]
  def change
    create_table :restaurants, id: false do |t|
      t.string   :id,         null: false
      t.string   :account_id, null: false
      t.string   :name,       null: false
      t.string   :timezone,   default: 'America/Bogota'
      t.string   :address
      t.string   :phone
      t.string   :currency,   default: 'COP'
      t.jsonb    :settings,   default: {}
      t.boolean  :active,     default: true
      t.timestamps
    end
    add_index :restaurants, :id,         unique: true
    add_index :restaurants, :account_id
    add_index :restaurants, [:account_id, :active]
  end
end
