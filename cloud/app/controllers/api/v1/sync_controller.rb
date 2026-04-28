module Api
  module V1
    class SyncController < BaseController

      def operations
        ops = params.require(:operations)
        return render_error("Maximo 500 operaciones", status: :unprocessable_entity) if ops.size > 500
        engine = SyncEngine.new(@edge_node)
        result = engine.process_batch(ops.map(&:to_unsafe_h).map(&:deep_symbolize_keys))
        render_ok({ processed: result.processed, ignored: result.ignored,
                    rejected: result.rejected, conflicts_resolved: result.conflicts_resolved,
                    results: result.results })
      end

      def status
        render_ok({
          node_id: @edge_node.id, server_time: Time.current.iso8601(3),
          node_status: @edge_node.sync_status,
          pending_downstream: { products: [], categories: [],
            restaurant_settings: { name: @restaurant.name, timezone: @restaurant.timezone } },
          last_sync_acknowledged: SyncLog.for_node(@edge_node.id).recent.first&.operation_id
        })
      end

      def heartbeat
        @edge_node.update!(
          version: params[:version], telemetry: params[:telemetry]&.to_unsafe_h || {},
          pending_operations: params[:pending_operations].to_i, last_seen_at: Time.current,
          sync_status: params[:pending_operations].to_i > 0 ? "degraded" : "healthy"
        )
        render_ok({ acknowledged: true, server_time: Time.current.iso8601(3) })
      end

      def link
        restaurant = Restaurant.find_by!(id: params[:restaurant_id])
        node_token      = SecureRandom.hex(32)
        node_token_hash = Digest::SHA256.hexdigest(node_token)
        edge_node = restaurant.edge_nodes.create!(
          account_id: restaurant.account_id, node_token_hash: node_token_hash,
          version: params[:node_version] || "unknown", hostname: params[:hostname],
          ip_address: request.remote_ip, sync_status: "healthy", last_seen_at: Time.current
        )
        render_ok({ node_id: edge_node.id, restaurant_id: restaurant.id, node_token: node_token,
                    restaurant: { id: restaurant.id, name: restaurant.name, timezone: restaurant.timezone },
                    initial_data: { categories: [], products: [], tables: [] } })
      end
    end
  end
end
