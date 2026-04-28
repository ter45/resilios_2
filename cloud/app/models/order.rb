class Order < ApplicationRecord
  self.primary_key = "id"
  belongs_to :restaurant
  belongs_to :edge_node, optional: true
  has_many :order_items, dependent: :destroy
  validates :restaurant_id, :table_label, :status, :opened_at, :synced_at, presence: true
end
