class SyncLog < ApplicationRecord
  self.primary_key = "id"
  belongs_to :edge_node
  belongs_to :restaurant
  validates :edge_node_id, :restaurant_id, :operation_id, :entity_id, presence: true
  validates :operation_id, uniqueness: true
  validates :result, inclusion: { in: %w[applied ignored conflict_resolved rejected] }
  validates :received_at, :processed_at, presence: true
  scope :for_node, ->(id) { where(edge_node_id: id) }
  scope :recent,   -> { order(received_at: :desc) }
  def self.already_processed?(operation_id)
    exists?(operation_id: operation_id)
  end
end
