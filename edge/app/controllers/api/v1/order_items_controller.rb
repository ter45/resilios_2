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
