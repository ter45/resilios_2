Write-Host "Creando modelos y controllers..." -ForegroundColor Cyan

# ── MODELOS ────────────────────────────────────────────────────────

$restaurant = @'
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
'@
Set-Content -Path "app\models\restaurant.rb" -Value $restaurant -Encoding UTF8
Write-Host "[OK] restaurant.rb" -ForegroundColor Green

$table_model = @'
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
'@
Set-Content -Path "app\models\table.rb" -Value $table_model -Encoding UTF8
Write-Host "[OK] table.rb" -ForegroundColor Green

$category = @'
class Category < ApplicationRecord
  self.primary_key = "id"
  belongs_to :restaurant
  has_many   :products, dependent: :destroy

  validates :name,          presence: true
  validates :restaurant_id, presence: true

  scope :active,  -> { where(active: true).order(:position) }
  scope :ordered, -> { order(:position, :name) }

  def active_products
    products.where(available: true).order(:position, :name)
  end
end
'@
Set-Content -Path "app\models\category.rb" -Value $category -Encoding UTF8
Write-Host "[OK] category.rb" -ForegroundColor Green

$product = @'
class Product < ApplicationRecord
  self.primary_key = "id"
  belongs_to :restaurant
  belongs_to :category
  has_many   :order_items

  validates :name,          presence: true
  validates :price,         presence: true, numericality: { greater_than: 0 }
  validates :restaurant_id, presence: true
  validates :category_id,   presence: true

  scope :available,   -> { where(available: true).order(:position, :name) }
  scope :by_category, ->(cat_id) { where(category_id: cat_id).available }
end
'@
Set-Content -Path "app\models\product.rb" -Value $product -Encoding UTF8
Write-Host "[OK] product.rb" -ForegroundColor Green

$order = @'
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
'@
Set-Content -Path "app\models\order.rb" -Value $order -Encoding UTF8
Write-Host "[OK] order.rb" -ForegroundColor Green

$order_item = @'
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
'@
Set-Content -Path "app\models\order_item.rb" -Value $order_item -Encoding UTF8
Write-Host "[OK] order_item.rb" -ForegroundColor Green

$sync_op = @'
class SyncOperation < ApplicationRecord
  self.primary_key = "id"

  STATUSES        = %w[pending processing synced failed].freeze
  OPERATION_TYPES = %w[create update delete].freeze
  ENTITY_TYPES    = %w[Order OrderItem Product Category Table].freeze
  MAX_RETRIES     = 5

  validates :restaurant_id,  presence: true
  validates :operation_type, presence: true, inclusion: { in: OPERATION_TYPES }
  validates :entity_type,    presence: true, inclusion: { in: ENTITY_TYPES }
  validates :entity_id,      presence: true
  validates :payload,        presence: true
  validates :status,         inclusion: { in: STATUSES }

  scope :pending,   -> { where(status: "pending").order(:created_at) }
  scope :failed,    -> { where(status: "failed") }
  scope :for_batch, ->(size) { pending.limit(size) }

  before_update :protect_immutable_fields

  def to_api_payload
    {
      id:             id,
      operation_type: operation_type,
      entity_type:    entity_type,
      entity_id:      entity_id,
      created_at:     created_at.iso8601(3),
      payload:        JSON.parse(payload)
    }
  end

  def mark_synced!
    update!(status: "synced", synced_at: Time.current)
  end

  def mark_failed!(error_message)
    update!(
      status:      retry_count < MAX_RETRIES ? "pending" : "failed",
      retry_count: retry_count + 1,
      last_error:  error_message
    )
  end

  def self.pending_count
    where(status: "pending").count
  end

  def self.oldest_pending_at
    where(status: "pending").minimum(:created_at)
  end

  def self.max_lag_seconds
    oldest = oldest_pending_at
    return 0 unless oldest
    (Time.current - oldest).to_i
  end

  private

  def protect_immutable_fields
    immutable = %w[operation_type entity_type entity_id payload]
    changed_immutable = (changed & immutable)
    if changed_immutable.any?
      errors.add(:base, "Cannot modify immutable fields: #{changed_immutable.join(', ')}")
      throw :abort
    end
  end
end
'@
Set-Content -Path "app\models\sync_operation.rb" -Value $sync_op -Encoding UTF8
Write-Host "[OK] sync_operation.rb" -ForegroundColor Green

# ── CONCERNS ──────────────────────────────────────────────────────

New-Item -ItemType Directory -Force -Path "app\models\concerns" | Out-Null

$syncable = @'
module Syncable
  extend ActiveSupport::Concern

  included do
    after_create  :enqueue_sync_create
    after_update  :enqueue_sync_update
    after_destroy :enqueue_sync_delete
  end

  def synced?
    respond_to?(:synced_at) && synced_at.present?
  end

  private

  def enqueue_sync_create
    enqueue_operation("create")
  end

  def enqueue_sync_update
    return if only_sync_fields_changed?
    enqueue_operation("update")
  end

  def enqueue_sync_delete
    enqueue_operation("delete")
  end

  def enqueue_operation(operation_type)
    SyncOperation.create!(
      restaurant_id:  restaurant_id_for_sync,
      operation_type: operation_type,
      entity_type:    self.class.name,
      entity_id:      id,
      payload:        build_sync_payload(operation_type),
      status:         "pending"
    )
  rescue => e
    Rails.logger.error "[Syncable] CRITICO: #{e.message}"
    raise ActiveRecord::Rollback, "SyncOperation creation failed: #{e.message}"
  end

  def build_sync_payload(operation_type)
    if operation_type == "delete"
      { id: id, deleted_at: Time.current.iso8601(3) }.to_json
    else
      as_sync_json.to_json
    end
  end

  def as_sync_json
    as_json
  end

  def only_sync_fields_changed?
    sync_fields = %w[sync_status synced_at updated_at]
    (saved_changes.keys - sync_fields).empty?
  end

  def restaurant_id_for_sync
    respond_to?(:restaurant_id) ? restaurant_id : nil
  end
end
'@
Set-Content -Path "app\models\concerns\syncable.rb" -Value $syncable -Encoding UTF8
Write-Host "[OK] concerns/syncable.rb" -ForegroundColor Green

# ── APPLICATION RECORD ────────────────────────────────────────────

$app_record = @'
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  self.implicit_order_column = "created_at"
  before_create :set_ulid_primary_key

  private

  def set_ulid_primary_key
    self.id ||= generate_ulid
  end

  ENCODING = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".chars.freeze

  def generate_ulid
    t = (Time.now.to_f * 1000).to_i
    encode_time(t) + encode_random(16)
  end

  def encode_time(time_ms)
    result = []
    mod = time_ms
    10.times do
      result.unshift ENCODING[mod & 31]
      mod >>= 5
    end
    result.join
  end

  def encode_random(length)
    length.times.map { ENCODING[SecureRandom.random_number(32)] }.join
  end
end
'@
Set-Content -Path "app\models\application_record.rb" -Value $app_record -Encoding UTF8
Write-Host "[OK] application_record.rb" -ForegroundColor Green

# ── CONTROLLERS ───────────────────────────────────────────────────

New-Item -ItemType Directory -Force -Path "app\controllers\api\v1" | Out-Null

$base_ctrl = @'
module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_device!
      before_action :set_restaurant

      rescue_from ActiveRecord::RecordNotFound,       with: :not_found
      rescue_from ActiveRecord::RecordInvalid,        with: :unprocessable
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      def authenticate_device!
        token = request.headers["Authorization"]&.gsub(/^Bearer /, "") || params[:device_token]
        render json: { error: "No autorizado" }, status: :unauthorized unless valid_token?(token)
      end

      def valid_token?(token)
        return false unless token.present?
        ActiveSupport::SecurityUtils.secure_compare(
          token,
          ENV.fetch("EDGE_DEVICE_TOKEN", "dev-token-change-in-production")
        )
      end

      def set_restaurant
        @restaurant = Restaurant.first
        render json: { error: "Restaurante no configurado" }, status: :service_unavailable unless @restaurant
      end

      def render_ok(data, meta: nil)
        body = { data: data }
        body[:meta] = meta if meta
        render json: body, status: :ok
      end

      def render_created(data)
        render json: { data: data }, status: :created
      end

      def render_error(message, status: :unprocessable_entity, errors: nil)
        body = { error: message }
        body[:errors] = errors if errors
        render json: body, status: status
      end

      def not_found(exception)
        render json: { error: "No encontrado: #{exception.message}" }, status: :not_found
      end

      def unprocessable(exception)
        render json: { error: "Validacion fallida", errors: exception.record.errors.full_messages },
               status: :unprocessable_entity
      end

      def bad_request(exception)
        render json: { error: "Parametro requerido: #{exception.param}" }, status: :bad_request
      end
    end
  end
end
'@
Set-Content -Path "app\controllers\api\v1\base_controller.rb" -Value $base_ctrl -Encoding UTF8
Write-Host "[OK] base_controller.rb" -ForegroundColor Green

$status_ctrl = @'
module Api
  module V1
    class StatusController < BaseController
      skip_before_action :authenticate_device!, only: [:health]
      skip_before_action :set_restaurant,       only: [:health]

      def health
        render json: { status: "ok", version: "1.0.0", time: Time.current.iso8601 }, status: :ok
      end

      def show
        pending_ops = SyncOperation.pending_count
        lag_seconds = SyncOperation.max_lag_seconds

        render_ok({
          node_id:      ENV.fetch("RESILIOS_NODE_ID", "unknown"),
          version:      "1.0.0",
          restaurant:   { id: @restaurant.id, name: @restaurant.name },
          connectivity: {
            status:       @restaurant.sync_status,
            last_sync_at: @restaurant.last_sync_at&.iso8601(3),
            lag_seconds:  lag_seconds,
            lag_human:    humanize_lag(lag_seconds)
          },
          queue: {
            pending_count:     pending_ops,
            oldest_pending_at: SyncOperation.oldest_pending_at&.iso8601(3)
          }
        })
      end

      private

      def humanize_lag(seconds)
        return "Al dia"        if seconds == 0
        return "#{seconds}s"   if seconds < 60
        return "#{(seconds / 60).round}min" if seconds < 3600
        "#{(seconds / 3600).round}h"
      end
    end
  end
end
'@
Set-Content -Path "app\controllers\api\v1\status_controller.rb" -Value $status_ctrl -Encoding UTF8
Write-Host "[OK] status_controller.rb" -ForegroundColor Green

$orders_ctrl = @'
module Api
  module V1
    class OrdersController < BaseController

      def index
        orders = @restaurant.orders.active.includes(:table, :order_items).order(opened_at: :desc)
        render_ok(
          orders.map { |o| serialize_order(o) },
          meta: { total: orders.size, pending_sync: SyncOperation.pending_count,
                  last_sync_at: @restaurant.last_sync_at&.iso8601 }
        )
      end

      def show
        render_ok(serialize_order(find_order, include_items: true))
      end

      def create
        ActiveRecord::Base.transaction do
          table = @restaurant.tables.find(order_params[:table_id])
          return render_error("Mesa #{table.display_name} ocupada", status: :conflict) if table.occupied?

          order = @restaurant.orders.create!(
            table: table, waiter_name: order_params[:waiter_name],
            status: "open", opened_at: Time.current
          )

          Array(order_params[:items]).each do |item_params|
            product = @restaurant.products.find(item_params[:product_id])
            return render_error("#{product.name} no disponible") unless product.available?
            order.order_items.create!(product: product, quantity: item_params[:quantity] || 1,
                                      notes: item_params[:notes])
          end

          table.update!(status: "occupied")
          render_created(serialize_order(order.reload, include_items: true))
        end
      end

      def update
        order = find_order
        order.update!(order_update_params)
        render_ok(serialize_order(order, include_items: true))
      end

      def close
        order = find_order
        return render_error("Pedido ya cerrado") if order.closed?
        ActiveRecord::Base.transaction { order.close! }
        render_ok(serialize_order(order, include_items: true))
      end

      def destroy
        order = find_order
        return render_error("No se puede cancelar pedido cerrado", status: :conflict) if order.closed?
        ActiveRecord::Base.transaction { order.cancel! }
        render_ok({ id: order.id, status: "cancelled" })
      end

      private

      def find_order
        @restaurant.orders.find(params[:id])
      end

      def order_params
        params.require(:order).permit(:table_id, :waiter_name, :notes,
                                      items: [:product_id, :quantity, :notes])
      end

      def order_update_params
        params.require(:order).permit(:waiter_name, :notes, :status)
      end

      def serialize_order(order, include_items: false)
        data = {
          id: order.id,
          table: { id: order.table.id, number: order.table.number, label: order.table.label },
          status: order.status, waiter_name: order.waiter_name,
          subtotal: order.subtotal.to_s, tax: order.tax.to_s, total: order.total.to_s,
          notes: order.notes, opened_at: order.opened_at&.iso8601(3),
          closed_at: order.closed_at&.iso8601(3), synced: order.synced?,
          sync_status: order.sync_status
        }
        if include_items
          data[:items] = order.order_items.map { |i|
            { id: i.id, product_id: i.product_id, product_name: i.product_name,
              unit_price: i.unit_price.to_s, quantity: i.quantity,
              subtotal: i.subtotal.to_s, notes: i.notes, status: i.status }
          }
        end
        data
      end
    end
  end
end
'@
Set-Content -Path "app\controllers\api\v1\orders_controller.rb" -Value $orders_ctrl -Encoding UTF8
Write-Host "[OK] orders_controller.rb" -ForegroundColor Green

$tables_ctrl = @'
module Api
  module V1
    class TablesController < BaseController
      def index
        tables = @restaurant.tables.order(:number)
        render_ok(tables.map { |t| serialize_table(t) })
      end

      def show
        render_ok(serialize_table(find_table, include_order: true))
      end

      def update
        table = find_table
        table.update!(params.require(:table).permit(:status, :label, :capacity))
        render_ok(serialize_table(table))
      end

      private

      def find_table
        @restaurant.tables.find(params[:id])
      end

      def serialize_table(table, include_order: false)
        data = { id: table.id, number: table.number, label: table.label,
                 capacity: table.capacity, status: table.status }
        if include_order && table.occupied?
          order = table.current_order
          data[:current_order] = order ? { id: order.id, total: order.total.to_s,
                                           items_count: order.items_count,
                                           opened_at: order.opened_at&.iso8601(3) } : nil
        end
        data
      end
    end
  end
end
'@
Set-Content -Path "app\controllers\api\v1\tables_controller.rb" -Value $tables_ctrl -Encoding UTF8
Write-Host "[OK] tables_controller.rb" -ForegroundColor Green

$menu_ctrl = @'
module Api
  module V1
    class MenuController < BaseController
      def index
        categories = @restaurant.categories.active.includes(:products)
        render_ok(categories.map { |cat|
          { id: cat.id, name: cat.name, position: cat.position,
            products: cat.active_products.map { |p| serialize_product(p) } }
        })
      end

      def products
        render_ok(@restaurant.products.available.map { |p| serialize_product(p) })
      end

      private

      def serialize_product(p)
        { id: p.id, name: p.name, description: p.description,
          price: p.price.to_s, category_id: p.category_id,
          available: p.available, image_url: p.image_url }
      end
    end
  end
end
'@
Set-Content -Path "app\controllers\api\v1\menu_controller.rb" -Value $menu_ctrl -Encoding UTF8
Write-Host "[OK] menu_controller.rb" -ForegroundColor Green

$kds_ctrl = @'
module Api
  module V1
    class KdsController < BaseController
      def queue
        items = OrderItem
          .joins(:order)
          .where(orders: { restaurant_id: @restaurant.id, status: %w[open in_progress] })
          .where(order_items: { status: %w[pending preparing] })
          .includes(:order)
          .order("orders.opened_at ASC, order_items.created_at ASC")
        render_ok(items.map { |i| serialize_kds_item(i) })
      end

      def orders
        orders = @restaurant.orders.active.includes(:table, order_items: :product).order(opened_at: :asc)
        render_ok(orders.map { |o|
          { id: o.id, table_number: o.table.number, waiter_name: o.waiter_name,
            status: o.status, opened_at: o.opened_at.iso8601(3),
            waiting_minutes: ((Time.current - o.opened_at) / 60).round,
            items: o.order_items.active.map { |i|
              { id: i.id, product_name: i.product_name,
                quantity: i.quantity, notes: i.notes, status: i.status }
            }}
        })
      end

      def item_ready
        item = find_kds_item
        item.mark_ready!
        check_order_completion(item.order)
        render_ok({ id: item.id, status: item.status })
      end

      def order_ready
        order = @restaurant.orders.find(params[:id])
        ActiveRecord::Base.transaction do
          order.order_items.where(status: %w[pending preparing]).each(&:mark_ready!)
          order.mark_ready!
        end
        render_ok({ id: order.id, status: order.status })
      end

      private

      def find_kds_item
        OrderItem.joins(:order).where(orders: { restaurant_id: @restaurant.id }).find(params[:id])
      end

      def check_order_completion(order)
        all_ready = order.order_items.where.not(status: "cancelled").all? { |i| i.status == "ready" }
        order.mark_ready! if all_ready
      end

      def serialize_kds_item(item)
        { id: item.id, order_id: item.order_id, table_number: item.order.table.number,
          product_name: item.product_name, quantity: item.quantity, notes: item.notes,
          status: item.status, waiting_since: item.created_at.iso8601(3),
          waiting_minutes: ((Time.current - item.created_at) / 60).round }
      end
    end
  end
end
'@
Set-Content -Path "app\controllers\api\v1\kds_controller.rb" -Value $kds_ctrl -Encoding UTF8
Write-Host "[OK] kds_controller.rb" -ForegroundColor Green

$order_items_ctrl = @'
module Api
  module V1
    class OrderItemsController < BaseController
      before_action :set_order

      def create
        return render_error("Pedido cerrado") if @order.closed?
        product = @restaurant.products.find(params.require(:item)[:product_id])
        return render_error("#{product.name} no disponible") unless product.available?
        item = @order.order_items.create!(
          product: product,
          quantity: params.require(:item)[:quantity] || 1,
          notes: params.require(:item)[:notes]
        )
        render_created(serialize_item(item))
      end

      def update
        item = find_item
        item.update!(params.require(:item).permit(:quantity, :notes))
        render_ok(serialize_item(item))
      end

      def destroy
        find_item.cancel!
        render_ok({ id: params[:id], status: "cancelled" })
      end

      def update_status
        item = find_item
        case params.require(:status)
        when "preparing" then item.start_preparing!
        when "ready"     then item.mark_ready!
        when "served"    then item.mark_served!
        when "cancelled" then item.cancel!
        else return render_error("Estado invalido")
        end
        render_ok(serialize_item(item))
      end

      private

      def set_order
        @order = @restaurant.orders.find(params[:order_id])
      end

      def find_item
        @order.order_items.find(params[:id])
      end

      def serialize_item(item)
        { id: item.id, order_id: item.order_id, product_id: item.product_id,
          product_name: item.product_name, unit_price: item.unit_price.to_s,
          quantity: item.quantity, subtotal: item.subtotal.to_s,
          notes: item.notes, status: item.status }
      end
    end
  end
end
'@
Set-Content -Path "app\controllers\api\v1\order_items_controller.rb" -Value $order_items_ctrl -Encoding UTF8
Write-Host "[OK] order_items_controller.rb" -ForegroundColor Green

Write-Host "`nTodo listo. Ejecuta:" -ForegroundColor Cyan
Write-Host "  bundle exec rails server" -ForegroundColor White
