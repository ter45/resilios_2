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
