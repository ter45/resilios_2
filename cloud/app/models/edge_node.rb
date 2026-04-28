class EdgeNode < ApplicationRecord
  self.primary_key = "id"
  belongs_to :account
  belongs_to :restaurant
  has_many :sync_logs, dependent: :destroy
  has_many :orders, dependent: :destroy, foreign_key: :edge_node_id
  validates :account_id, :restaurant_id, :node_token_hash, presence: true
  validates :node_token_hash, uniqueness: true
  def self.authenticate(node_token)
    find_by(node_token_hash: Digest::SHA256.hexdigest(node_token))
  end
  def mark_seen!
    update_columns(last_seen_at: Time.current)
  end
  def mark_synced!(pending_count: 0)
    update_columns(last_sync_at: Time.current, last_seen_at: Time.current,
                   sync_status: "healthy", pending_operations: pending_count)
  end
end
