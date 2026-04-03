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
