# ══════════════════════════════════════════════════════════════════
#  edge/app/models/order_item.rb
# ══════════════════════════════════════════════════════════════════

class OrderItem < ApplicationRecord
  include Syncable

  # ── Asociaciones ──────────────────────────────────────────────
  belongs_to :order
  belongs_to :product

  # ── Enums ─────────────────────────────────────────────────────
  STATUSES = %w[pending preparing ready served cancelled].freeze

  # ── Validaciones ──────────────────────────────────────────────
  validates :order_id,     presence: true
  validates :product_id,   presence: true
  validates :product_name, presence: true
  validates :unit_price,   presence: true, numericality: { greater_than: 0 }
  validates :quantity,     presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :status,       inclusion: { in: STATUSES }

  # ── Callbacks ─────────────────────────────────────────────────
  before_create  :snapshot_product_data
  before_save    :calculate_subtotal
  after_save     :update_order_total

  # ── Scopes ────────────────────────────────────────────────────
  scope :pending,    -> { where(status: "pending") }
  scope :preparing,  -> { where(status: "preparing") }
  scope :ready,      -> { where(status: "ready") }
  scope :active,     -> { where.not(status: "cancelled") }

  # ── Transiciones ──────────────────────────────────────────────

  def start_preparing!
    update!(status: "preparing")
  end

  def mark_ready!
    update!(status: "ready")
  end

  def mark_served!
    update!(status: "served")
  end

  def cancel!
    update!(status: "cancelled")
  end

  # ── Serialización para Sync ───────────────────────────────────

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

  def restaurant_id_for_sync
    order.restaurant_id
  end

  private

  # Snapshot del nombre y precio en el momento del pedido
  # Esto protege contra cambios de menú futuros
  def snapshot_product_data
    self.product_name ||= product.name
    self.unit_price   ||= product.price
  end

  def calculate_subtotal
    self.subtotal = unit_price * quantity
  end

  def update_order_total
    order.send(:calculate_totals)
    order.save!(validate: false)
  end
end


# ══════════════════════════════════════════════════════════════════
#  edge/app/models/restaurant.rb
# ══════════════════════════════════════════════════════════════════

class Restaurant < ApplicationRecord
  # El restaurante NO incluye Syncable — es configuración,
  # no datos transaccionales. Se sincroniza descendentemente desde Cloud.

  # ── Asociaciones ──────────────────────────────────────────────
  has_many :tables,     dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :products,   through: :categories
  has_many :orders,     dependent: :destroy
  has_many :sync_operations, dependent: :destroy

  # ── Validaciones ──────────────────────────────────────────────
  validates :name,       presence: true
  validates :node_token, presence: true

  # ── Consultas de estado ───────────────────────────────────────

  def pending_sync_count
    sync_operations.where(status: "pending").count
  end

  def last_sync_age_seconds
    return nil unless last_sync_at
    (Time.current - last_sync_at).to_i
  end

  def sync_status
    lag = SyncOperation.max_lag_seconds
    if lag == 0
      "synced"
    elsif lag < 300    # menos de 5 minutos
      "pending"
    else
      "degraded"
    end
  end
end


# ══════════════════════════════════════════════════════════════════
#  edge/app/models/table.rb
# ══════════════════════════════════════════════════════════════════

class Table < ApplicationRecord
  # Las mesas NO sincronizan su estado al Cloud en tiempo real
  # (el estado es local y se reconstruye desde los pedidos)

  # ── Asociaciones ──────────────────────────────────────────────
  belongs_to :restaurant
  has_many   :orders

  # ── Enums ─────────────────────────────────────────────────────
  STATUSES = %w[available occupied reserved].freeze

  # ── Validaciones ──────────────────────────────────────────────
  validates :number,        presence: true
  validates :restaurant_id, presence: true
  validates :status,        inclusion: { in: STATUSES }

  # ── Scopes ────────────────────────────────────────────────────
  scope :available, -> { where(status: "available") }
  scope :occupied,  -> { where(status: "occupied") }

  # ── API pública ───────────────────────────────────────────────

  def available?
    status == "available"
  end

  def occupied?
    status == "occupied"
  end

  def current_order
    orders.active.order(opened_at: :desc).first
  end

  def display_name
    label.present? ? "#{number} — #{label}" : number
  end
end


# ══════════════════════════════════════════════════════════════════
#  edge/app/models/category.rb
# ══════════════════════════════════════════════════════════════════

class Category < ApplicationRecord
  # Sincronización descendente únicamente (Cloud -> Edge)
  # No genera SyncOperations ascendentes

  belongs_to :restaurant
  has_many   :products, dependent: :destroy

  validates :name,          presence: true
  validates :restaurant_id, presence: true

  scope :active,   -> { where(active: true).order(:position) }
  scope :ordered,  -> { order(:position, :name) }

  def active_products
    products.where(available: true).order(:position, :name)
  end
end


# ══════════════════════════════════════════════════════════════════
#  edge/app/models/product.rb
# ══════════════════════════════════════════════════════════════════

class Product < ApplicationRecord
  # Sincronización descendente únicamente (Cloud -> Edge)
  # El menú es server-authoritative: Cloud siempre gana

  belongs_to :restaurant
  belongs_to :category
  has_many   :order_items

  validates :name,          presence: true
  validates :price,         presence: true, numericality: { greater_than: 0 }
  validates :restaurant_id, presence: true
  validates :category_id,   presence: true

  scope :available, -> { where(available: true).order(:position, :name) }
  scope :by_category, ->(cat_id) { where(category_id: cat_id).available }

  def formatted_price(currency: "COP")
    "$#{price.to_s(:delimited)}"
  end
end
