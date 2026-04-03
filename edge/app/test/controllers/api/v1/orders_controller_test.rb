# ══════════════════════════════════════════════════════════════════
#  edge/test/controllers/api/v1/orders_controller_test.rb
#
#  Tests de integración para el endpoint principal del POS.
#  Validan el comportamiento completo: request → response → DB.
# ══════════════════════════════════════════════════════════════════

require "test_helper"

module Api
  module V1
    class OrdersControllerTest < ActionDispatch::IntegrationTest
      include ApiRequestHelpers

      setup do
        @ctx        = setup_full_restaurant
        @restaurant = @ctx[:restaurant]
        @table      = @ctx[:tables].first
        @product1   = @ctx[:products].first
        @product2   = @ctx[:products].last
      end

      # ── GET /api/v1/orders ──────────────────────────────────

      test "GET /orders retorna lista de pedidos activos" do
        order1 = create_order(@restaurant, @table)
        table2 = @ctx[:tables].last
        order2 = create_order(@restaurant, table2)
        order2.update_columns(status: "closed")

        get "/api/v1/orders", headers: auth_headers

        assert_response :ok
        data = json_response["data"]
        assert_includes data.map { |o| o["id"] }, order1.id
        assert_not_includes data.map { |o| o["id"] }, order2.id
      end

      test "GET /orders incluye meta con pending_sync count" do
        create_order(@restaurant, @table)

        get "/api/v1/orders", headers: auth_headers

        meta = json_response["meta"]
        assert meta.key?("pending_sync")
        assert meta.key?("last_sync_at")
      end

      test "GET /orders retorna 401 sin token" do
        get "/api/v1/orders"
        assert_response :unauthorized
      end

      # ── GET /api/v1/orders/:id ──────────────────────────────

      test "GET /orders/:id retorna detalle con items" do
        order = create_order(@restaurant, @table)
        create_order_item(order, @product1, quantity: 2)

        get "/api/v1/orders/#{order.id}", headers: auth_headers

        assert_response :ok
        data = json_response["data"]
        assert_equal order.id, data["id"]
        assert data.key?("items")
        assert_equal 1, data["items"].size
        assert_equal 2, data["items"].first["quantity"]
      end

      test "GET /orders/:id retorna 404 para pedido inexistente" do
        get "/api/v1/orders/id-no-existe", headers: auth_headers
        assert_response :not_found
      end

      # ── POST /api/v1/orders ─────────────────────────────────

      test "POST /orders crea pedido con items y genera SyncOperation" do
        assert_difference ["Order.count", "SyncOperation.count"], 1 do
          assert_difference "OrderItem.count", 2 do
            post_json "/api/v1/orders", {
              order: {
                table_id:    @table.id,
                waiter_name: "Carlos",
                items: [
                  { product_id: @product1.id, quantity: 2, notes: "Sin chicharrón" },
                  { product_id: @product2.id, quantity: 1 }
                ]
              }
            }
          end
        end

        assert_response :created
        data = json_response["data"]
        assert_equal "open", data["status"]
        assert_equal 2, data["items"].size
        assert_equal "pending", data["sync_status"]
      end

      test "POST /orders actualiza el estado de la mesa a occupied" do
        post_json "/api/v1/orders", {
          order: { table_id: @table.id, waiter_name: "Carlos" }
        }

        assert_equal "occupied", @table.reload.status
      end

      test "POST /orders retorna conflict si la mesa ya tiene pedido abierto" do
        create_order(@restaurant, @table)
        @table.update!(status: "occupied")

        assert_no_difference "Order.count" do
          post_json "/api/v1/orders", {
            order: { table_id: @table.id, waiter_name: "María" }
          }
        end

        assert_response :conflict
      end

      test "POST /orders retorna error si el producto no está disponible" do
        @product1.update!(available: false)

        assert_no_difference "Order.count" do
          post_json "/api/v1/orders", {
            order: {
              table_id: @table.id,
              items: [{ product_id: @product1.id, quantity: 1 }]
            }
          }
        end

        assert_response :unprocessable_entity
      end

      test "POST /orders calcula totales correctamente incluyendo IVA 19%" do
        post_json "/api/v1/orders", {
          order: {
            table_id: @table.id,
            items: [{ product_id: @product1.id, quantity: 2 }]  # 2 × 28.000 = 56.000
          }
        }

        data = json_response["data"]
        assert_equal "56000.0",  data["subtotal"]
        assert_equal "10640.0",  data["tax"]      # 56.000 × 19%
        assert_equal "66640.0",  data["total"]
      end

      # ── POST /api/v1/orders/:id/close ───────────────────────

      test "POST /orders/:id/close cierra el pedido y libera la mesa" do
        order = create_order(@restaurant, @table)
        @table.update!(status: "occupied")

        post "/api/v1/orders/#{order.id}/close", headers: auth_headers

        assert_response :ok
        assert_equal "closed",    order.reload.status
        assert_equal "available", @table.reload.status
        assert order.reload.closed_at.present?
      end

      test "POST /orders/:id/close genera SyncOperation de update" do
        order = create_order(@restaurant, @table)

        assert_difference "SyncOperation.count", 1 do
          post "/api/v1/orders/#{order.id}/close", headers: auth_headers
        end

        op = SyncOperation.last
        assert_equal "update", op.operation_type
        assert_equal order.id, op.entity_id
      end

      # ── DELETE /api/v1/orders/:id ───────────────────────────

      test "DELETE /orders/:id cancela el pedido" do
        order = create_order(@restaurant, @table)

        delete "/api/v1/orders/#{order.id}", headers: auth_headers

        assert_response :ok
        assert_equal "cancelled", order.reload.status
      end

      test "DELETE /orders/:id retorna conflict para pedido ya cerrado" do
        order = create_order(@restaurant, @table)
        order.update_columns(status: "closed")

        delete "/api/v1/orders/#{order.id}", headers: auth_headers

        assert_response :conflict
      end
    end
  end
end
