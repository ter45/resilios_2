class CreateSyncLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_logs, id: false do |t|
      t.string   :id,             null: false
      t.string   :edge_node_id,   null: false
      t.string   :restaurant_id,  null: false
      t.string   :operation_id,   null: false
      t.string   :operation_type, null: false
      t.string   :entity_type,    null: false
      t.string   :entity_id,      null: false
      t.jsonb    :payload,        null: false
      t.string   :result,         null: false
      t.jsonb    :conflict_detail
      t.integer  :processing_ms
      t.datetime :received_at,    null: false
      t.datetime :processed_at,   null: false
    end
    add_index :sync_logs, :id,           unique: true
    add_index :sync_logs, :edge_node_id
    add_index :sync_logs, :operation_id, unique: true
    add_index :sync_logs, [:edge_node_id, :received_at]
    add_index :sync_logs, :result
    add_index :sync_logs, :entity_id
  end
end
