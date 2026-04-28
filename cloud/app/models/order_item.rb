class OrderItem < ApplicationRecord
  self.primary_key = "id"
  belongs_to :order
  validates :order_id, :product_name, :unit_price, :quantity, :synced_at, presence: true
end
