class Order < ApplicationRecord
  self.primary_key = "id"
  include Syncable

  belongs_to :restaurant
  belongs_to :table
  has_many   :order_items, dependent: :destroy

  STATUSES = %w[open in_progress ready closed cancelled].freeze

  validates :restaurant_id, presence: true
  validates :table_id,      presence: true
  validates :status,        presence: true, inclusion: { in: STATUSES }
  validates :opened_at,     presence: true

  before_create :set_opened_at
  before_save   :calculate_totals

  scope :open,     -> { where(status: "open") }
  scope :active,   -> { where(status: %w[open in_progress ready]) }
  scope :closed,   -> { where(status: "closed") }
  scope :unsynced, -> { where(sync_status: "pending") }
  scope :today,    -> { where("opened_at >= ?", Time.current.beginning_of_day) }

  def start!
    update!(status: "in_progress")
  end

  def mark_ready!
    update!(status: "ready")
  end

  def close!(closed_at: Time.current)
    transaction do
      update!(status: "closed", closed_at: closed_at)
      table.update!(status: "available")
    end
  end

  def cancel!
    transaction do
      update!(status: "cancelled")
      table.update!(status: "available")
    end
  end

  def closed?
    status == "closed"
  end

  def synced?
    synced_at.present?
  end

  def items_count
    order_items.sum(:quantity)
  end

  def as_sync_json
    {
      id:            id,
      restaurant_id: restaurant_id,
      table_id:      table_id,
      table_label:   table.number,
      status:        status,
      waiter_name:   waiter_name,
      subtotal:      subtotal.to_s,
      tax:           tax.to_s,
      total:         total.to_s,
      notes:         notes,
      opened_at:     opened_at&.iso8601(3),
      closed_at:     closed_at&.iso8601(3),
      created_at:    created_at.iso8601(3),
      updated_at:    updated_at.iso8601(3)
    }
  end

  private

  def set_opened_at
    self.opened_at ||= Time.current
  end

  def calculate_totals
    item_total = order_items.reject(&:marked_for_destruction?).sum { |i| i.subtotal || 0 }
    self.subtotal = item_total
    self.tax      = (subtotal * 0.19).round(2)
    self.total    = subtotal + tax
  end
end
