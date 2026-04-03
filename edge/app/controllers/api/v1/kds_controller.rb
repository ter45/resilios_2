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
