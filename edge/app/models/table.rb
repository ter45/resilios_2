class Table < ApplicationRecord
  self.primary_key = "id"
  belongs_to :restaurant
  has_many   :orders

  STATUSES = %w[available occupied reserved].freeze

  validates :number,        presence: true
  validates :restaurant_id, presence: true
  validates :status,        inclusion: { in: STATUSES }

  scope :available, -> { where(status: "available") }
  scope :occupied,  -> { where(status: "occupied") }

  def available?
    status == "available"
  end

  def occupied?
    status == "occupied"
  end

  def current_order
    orders.where(status: %w[open in_progress ready]).order(opened_at: :desc).first
  end

  def display_name
    label.present? ? "#{number} - #{label}" : number
  end
end
