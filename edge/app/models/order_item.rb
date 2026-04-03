class OrderItem < ApplicationRecord
  self.primary_key = "id"
  include Syncable

  belongs_to :order
  belongs_to :product

  STATUSES = %w[pending preparing ready served cancelled].freeze

  validates :order_id,     presence: true
  validates :product_id,   presence: true
  validates :product_name, presence: true
  validates :unit_price,   presence: true, numericality: { greater_than: 0 }
  validates :quantity,     presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :status,       inclusion: { in: STATUSES }

  before_create :snapshot_product_data
  before_save   :calculate_subtotal

  scope :pending,   -> { where(status: "pending") }
  scope :preparing, -> { where(status: "preparing") }
  scope :ready,     -> { where(status: "ready") }
  scope :active,    -> { where.not(status: "cancelled") }

  def start_preparing!; update!(status: "preparing"); end
  def mark_ready!;      update!(status: "ready");     end
  def mark_served!;     update!(status: "served");    end
  def cancel!;          update!(status: "cancelled"); end

  def as_sync_json
    {
      id:           id,
      order_id:     order_id,
      product_id:   product_id,
      product_name: product_name,
      unit_price:   unit_price.to_s,
      quantity:     quantity,
      subtotal:     subtotal.to_s,
      notes:        notes,
      status:       status,
      created_at:   created_at.iso8601(3),
      updated_at:   updated_at.iso8601(3)
    }
  end

  def restaurant_id
    order.restaurant_id
  end

  private

  def snapshot_product_data
    self.product_name ||= product.name
    self.unit_price   ||= product.price
  end

  def calculate_subtotal
    self.subtotal = unit_price * quantity
  end
end
