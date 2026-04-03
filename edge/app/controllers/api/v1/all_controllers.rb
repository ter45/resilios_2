# ══════════════════════════════════════════════════════════════════
#  edge/app/controllers/api/v1/order_items_controller.rb
# ══════════════════════════════════════════════════════════════════

module Api
  module V1
    class OrderItemsController < BaseController
      before_action :set_order
      before_action :set_item, only: %i[update destroy prepare ready serve]

      # GET /api/v1/orders/:order_id/items
      def index
        render_collection(@order.order_items.active, serializer: method(:serialize_item))
      end

      # POST /api/v1/orders/:order_id/items
      def create
        @item = @order.order_items.build(item_params)
        @item.save!
        broadcast_to_kds(@order.reload)
        render_success(serialize_item(@item), status: :created)
      end

      # PATCH /api/v1/orders/:order_id/items/:id
      def update
        @item.update!(update_params)
        render_success(serialize_item(@item))
      end

      # DELETE /api/v1/orders/:order_id/items/:id
      def destroy
        @item.cancel!
        render_success({ id: @item.id, status: "cancelled" })
      end

      # POST /api/v1/orders/:order_id/items/:id/prepare
      def prepare
        @item.start_preparing!
        render_success(serialize_item(@item))
      end

      # POST /api/v1/orders/:order_id/items/:id/ready
      def ready
        @item.mark_ready!
        check_order_ready
        render_success(serialize_item(@item))
      end

      # POST /api/v1/orders/:order_id/items/:id/serve
      def serve
        @item.mark_served!
        render_success(serialize_item(@item))
      end

      private

      def set_order
        @order = @restaurant.orders.find(params[:order_id])
      end

      def set_item
        @item = @order.order_items.find(params[:id])
      end

      def item_params
        params.require(:item).permit(:product_id, :quantity, :notes)
      end

      def update_params
        params.require(:item).permit(:quantity, :notes)
      end

      def check_order_ready
        all_ready = @order.order_items.active.all? { |i| %w[ready served].include?(i.status) }
        @order.mark_ready! if all_ready
      end

      def broadcast_to_kds(order)
        ActionCable.server.broadcast("kds_channel", {
          event:    "order_updated",
          order_id: order.id,
          table:    order.table.display_name,
          status:   order.status,
          items:    order.order_items.active.map { |i| serialize_item(i) }
        })
      rescue => e
        Rails.logger.warn "[OrderItemsController] KDS broadcast falló: #{e.message}"
      end

      def serialize_item(item)
        {
          id:           item.id,
          order_id:     item.order_id,
          product_id:   item.product_id,
          product_name: item.product_name,
          unit_price:   item.unit_price.to_s,
          quantity:     item.quantity,
          subtotal:     item.subtotal.to_s,
          notes:        item.notes,
          status:       item.status,
          created_at:   item.created_at.iso8601(3)
        }
      end
    end
  end
end


# ══════════════════════════════════════════════════════════════════
#  edge/app/controllers/api/v1/tables_controller.rb
# ══════════════════════════════════════════════════════════════════

module Api
  module V1
    class TablesController < BaseController

      # GET /api/v1/tables
      def index
        tables = @restaurant.tables
                            .includes(orders: :order_items)
                            .order(:number)

        render_collection(tables, serializer: method(:serialize_table))
      end

      # GET /api/v1/tables/:id
      def show
        table = @restaurant.tables.find(params[:id])
        render_success(serialize_table_detail(table))
      end

      private

      def serialize_table(table)
        active_order = table.current_order
        {
          id:           table.id,
          number:       table.number,
          label:        table.label,
          status:       table.status,
          capacity:     table.capacity,
          active_order: active_order ? {
            id:          active_order.id,
            status:      active_order.status,
            total:       active_order.total.to_s,
            items_count: active_order.order_items.active.size,
            waiter_name: active_order.waiter_name,
            opened_at:   active_order.opened_at.iso8601(3)
          } : nil
        }
      end

      def serialize_table_detail(table)
        result = serialize_table(table)
        if table.occupied? && table.current_order
          result[:active_order][:items] = table.current_order
            .order_items.active
            .map { |i| { name: i.product_name, qty: i.quantity, status: i.status } }
        end
        result
      end
    end
  end
end


# ══════════════════════════════════════════════════════════════════
#  edge/app/controllers/api/v1/products_controller.rb
# ══════════════════════════════════════════════════════════════════

module Api
  module V1
    class ProductsController < BaseController

      # GET /api/v1/products
      def index
        products = @restaurant.products.available.includes(:category)
        render_collection(products, serializer: method(:serialize_product))
      end

      # GET /api/v1/products/by_category
      def by_category
        categories = @restaurant.categories.active.includes(:products)
        data = categories.map do |cat|
          {
            id:       cat.id,
            name:     cat.name,
            position: cat.position,
            products: cat.active_products.map { |p| serialize_product(p) }
          }
        end
        render_success(data, meta: { total_products: data.sum { |c| c[:products].size } })
      end

      private

      def serialize_product(product)
        {
          id:            product.id,
          name:          product.name,
          description:   product.description,
          price:         product.price.to_s,
          category_id:   product.category_id,
          category_name: product.category.name,
          available:     product.available,
          image_url:     product.image_url
        }
      end
    end
  end
end


# ══════════════════════════════════════════════════════════════════
#  edge/app/controllers/api/v1/status_controller.rb
#
#  Consultado por la PWA cada 30s para el indicador de conectividad
# ══════════════════════════════════════════════════════════════════

module Api
  module V1
    class StatusController < BaseController

      # GET /api/v1/status
      def show
        render json: {
          node_id:            ENV.fetch("RESILIOS_NODE_ID", "unknown"),
          restaurant_name:    @restaurant.name,
          sync_status:        @restaurant.sync_status,
          pending_operations: SyncOperation.pending_count,
          last_sync_at:       @restaurant.last_sync_at&.iso8601(3),
          last_sync_age_sec:  @restaurant.last_sync_age_seconds,
          oldest_pending_age: SyncOperation.max_lag_seconds,
          tables_summary: {
            total:     @restaurant.tables.count,
            available: @restaurant.tables.available.count,
            occupied:  @restaurant.tables.occupied.count
          },
          today_orders: {
            total:  @restaurant.orders.today.count,
            open:   @restaurant.orders.today.open.count,
            closed: @restaurant.orders.today.closed.count
          },
          timestamp: Time.current.iso8601(3)
        }
      end
    end
  end
end


# ══════════════════════════════════════════════════════════════════
#  edge/app/controllers/health_controller.rb
#
#  GET /health — usado por Docker healthcheck. Sin autenticación.
# ══════════════════════════════════════════════════════════════════

class HealthController < ActionController::API
  def show
    db_ok = ActiveRecord::Base.connection.execute("SELECT 1") && true rescue false

    render json: {
      status:    db_ok ? "ok" : "degraded",
      database:  db_ok ? "ok" : "error",
      timestamp: Time.current.iso8601(3)
    }, status: db_ok ? :ok : :service_unavailable
  end
end
