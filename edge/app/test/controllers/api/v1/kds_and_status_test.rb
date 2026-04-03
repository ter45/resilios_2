# ══════════════════════════════════════════════════════════════════
#  edge/test/controllers/api/v1/kds_controller_test.rb
# ══════════════════════════════════════════════════════════════════

require "test_helper"

module Api
  module V1
    class KdsControllerTest < ActionDispatch::IntegrationTest
      include ApiRequestHelpers

      setup do
        @ctx        = setup_full_restaurant
        @restaurant = @ctx[:restaurant]
        @table      = @ctx[:tables].first
        @product1   = @ctx[:products].first
        @product2   = @ctx[:products].last
      end

      # ── GET /api/v1/kds/queue ──────────────────────────────

      test "GET /kds/queue retorna items pendientes ordenados por espera" do
        # Pedido antiguo (lleva más tiempo)
        order_viejo = create_order(@restaurant, @table)
        order_viejo.update_columns(opened_at: 20.minutes.ago)
        item_viejo = create_order_item(order_viejo, @product1)

        # Pedido reciente
        table2 = @ctx[:tables].last
        order_nuevo = create_order(@restaurant, table2)
        item_nuevo = create_order_item(order_nuevo, @product2)

        get "/api/v1/kds/queue", headers: auth_headers

        assert_response :ok
        items = json_response["data"]
        assert_equal 2, items.size

        # El más antiguo debe aparecer primero
        assert_equal item_viejo.id, items.first["id"],
          "El KDS debe mostrar primero los pedidos con más tiempo de espera"

        # Verificar campos del KDS
        first_item = items.first
        assert first_item.key?("table_number")
        assert first_item.key?("waiting_minutes")
        assert first_item.key?("product_name")
      end

      test "GET /kds/queue no incluye items de pedidos cerrados" do
        order = create_order(@restaurant, @table)
        create_order_item(order, @product1)
        order.update_columns(status: "closed")

        get "/api/v1/kds/queue", headers: auth_headers

        assert_response :ok
        assert_empty json_response["data"],
          "El KDS no debe mostrar items de pedidos cerrados"
      end

      # ── POST /api/v1/kds/items/:id/ready ──────────────────

      test "POST /kds/items/:id/ready marca el item como listo" do
        order = create_order(@restaurant, @table)
        item  = create_order_item(order, @product1)

        post "/api/v1/kds/items/#{item.id}/ready", headers: auth_headers

        assert_response :ok
        assert_equal "ready", item.reload.status
      end

      test "POST /kds/items/:id/ready marca el pedido como ready si todos los items están listos" do
        order = create_order(@restaurant, @table)
        item1 = create_order_item(order, @product1)
        item2 = create_order_item(order, @product2)

        # Marcar el primer item como listo
        item1.update_columns(status: "ready")

        # Marcar el segundo → todos listos → pedido pasa a ready
        post "/api/v1/kds/items/#{item2.id}/ready", headers: auth_headers

        assert_equal "ready", order.reload.status
      end

      # ── POST /api/v1/kds/orders/:id/ready ─────────────────

      test "POST /kds/orders/:id/ready marca todos los items y el pedido como listos" do
        order = create_order(@restaurant, @table)
        item1 = create_order_item(order, @product1)
        item2 = create_order_item(order, @product2)

        post "/api/v1/kds/orders/#{order.id}/ready", headers: auth_headers

        assert_response :ok
        assert_equal "ready", order.reload.status
        assert_equal "ready", item1.reload.status
        assert_equal "ready", item2.reload.status
      end
    end
  end
end


# ══════════════════════════════════════════════════════════════════
#  edge/test/controllers/api/v1/status_controller_test.rb
# ══════════════════════════════════════════════════════════════════

require "test_helper"

module Api
  module V1
    class StatusControllerTest < ActionDispatch::IntegrationTest
      include ApiRequestHelpers

      setup do
        @ctx        = setup_full_restaurant
        @restaurant = @ctx[:restaurant]
        @table      = @ctx[:tables].first
        @product    = @ctx[:products].first
      end

      # ── GET /health ────────────────────────────────────────

      test "GET /health responde 200 sin token (Docker healthcheck)" do
        get "/health"

        assert_response :ok
        body = json_response
        assert_equal "ok", body["status"]
        assert body.key?("version")
        assert body.key?("time")
      end

      # ── GET /api/v1/status ─────────────────────────────────

      test "GET /status retorna estado completo del nodo" do
        get "/api/v1/status", headers: auth_headers

        assert_response :ok
        data = json_response["data"]

        assert data.key?("node_id")
        assert data.key?("connectivity")
        assert data.key?("queue")
        assert data.key?("system")
        assert data.key?("restaurant")
      end

      test "GET /status muestra pending_count correcto" do
        # Crear pedidos que generan SyncOperations pendientes
        3.times { create_order(@restaurant, @table) }
        @table.update!(status: "available")

        get "/api/v1/status", headers: auth_headers

        queue = json_response["data"]["queue"]
        assert_equal 3, queue["pending_count"]
      end

      test "GET /status muestra lag_human legible" do
        get "/api/v1/status", headers: auth_headers

        connectivity = json_response["data"]["connectivity"]
        assert connectivity.key?("lag_human")

        # Con 0 operaciones pendientes, debe decir Al día
        assert_equal "Al día", connectivity["lag_human"]
      end

      test "GET /status retorna 401 sin token" do
        get "/api/v1/status"
        assert_response :unauthorized
      end
    end
  end
end
