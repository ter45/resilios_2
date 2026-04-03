class Restaurant < ApplicationRecord
  self.primary_key = "id"
  has_many :tables,          dependent: :destroy
  has_many :categories,      dependent: :destroy
  has_many :products,        through: :categories
  has_many :orders,          dependent: :destroy
  has_many :sync_operations, dependent: :destroy

  validates :name,       presence: true
  validates :node_token, presence: true

  def pending_sync_count
    sync_operations.where(status: "pending").count
  end

  def sync_status
    lag = SyncOperation.max_lag_seconds
    return "synced"   if lag == 0
    return "pending"  if lag < 300
    "degraded"
  end
end
