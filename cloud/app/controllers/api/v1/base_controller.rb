module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_node!
      rescue_from ActiveRecord::RecordNotFound,       with: :not_found
      rescue_from ActiveRecord::RecordInvalid,        with: :unprocessable
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      def authenticate_node!
        token   = request.headers["Authorization"]&.gsub(/^Bearer /, "")
        node_id = request.headers["X-Node-ID"]
        return render_unauthorized unless token.present? && node_id.present?
        @edge_node = EdgeNode.authenticate(token)
        return render_unauthorized unless @edge_node
        return render_unauthorized unless @edge_node.id == node_id
        @restaurant = @edge_node.restaurant
        @account    = @restaurant.account
        @edge_node.mark_seen!
      end

      def render_ok(data, meta: nil)
        body = { data: data }
        body[:meta] = meta if meta
        render json: body, status: :ok
      end

      def render_error(message, status: :unprocessable_entity)
        render json: { error: message }, status: status
      end

      def render_unauthorized
        render json: { error: "No autorizado" }, status: :unauthorized
      end

      def not_found(e)
        render json: { error: "No encontrado" }, status: :not_found
      end

      def unprocessable(e)
        render json: { error: "Validacion fallida", errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def bad_request(e)
        render json: { error: "Parametro requerido: #{e.param}" }, status: :bad_request
      end
    end
  end
end
