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
