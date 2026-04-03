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
