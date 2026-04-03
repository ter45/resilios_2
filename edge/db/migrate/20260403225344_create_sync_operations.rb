class CreateSyncOperations < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_operations, id: false do |t|
      t.string   :id,             null: false
      t.string   :restaurant_id,  null: false
      t.string   :operation_type, null: false
      t.string   :entity_type,    null: false
      t.string   :entity_id,      null: false
      t.text     :payload,        null: false
      t.string   :status,         default: "pending"
      t.integer  :retry_count,    default: 0
      t.text     :last_error
      t.datetime :created_at,     null: false
      t.datetime :synced_at
    end
    add_index :sync_operations, [:restaurant_id, :status]
    add_index :sync_operations, :status
    add_index :sync_operations, :created_at
    add_index :sync_operations, :entity_id
    execute "CREATE UNIQUE INDEX idx_sync_operations_id ON sync_operations(id);"
  end
end
