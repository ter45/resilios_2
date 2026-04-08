class CreateEdgeNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :edge_nodes, id: false do |t|
      t.string   :id,                 null: false
      t.string   :account_id,         null: false
      t.string   :restaurant_id,      null: false
      t.string   :node_token_hash,    null: false
      t.string   :version
      t.string   :ip_address
      t.string   :hostname
      t.jsonb    :telemetry,           default: {}
      t.string   :sync_status,        default: 'unknown'
      t.integer  :pending_operations, default: 0
      t.datetime :last_seen_at
      t.datetime :last_sync_at
      t.timestamps
    end
    add_index :edge_nodes, :id,              unique: true
    add_index :edge_nodes, :restaurant_id
    add_index :edge_nodes, :node_token_hash, unique: true
    add_index :edge_nodes, :last_seen_at
    add_index :edge_nodes, :sync_status
  end
end
