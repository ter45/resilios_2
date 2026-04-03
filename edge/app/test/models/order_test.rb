# ══════════════════════════════════════════════════════════════════
#  edge/test/models/order_test.rb
#
#  Tests del modelo Order: validaciones, transiciones de estado,
#  cálculo de totales y snapshots de precios.
# ══════════════════════════════════════════════════════════════════

require "test_helper"

class OrderTest < ActiveSupport::TestCase

  setup do
    @ctx        = setup_full_restaurant
    @restaurant = @ctx[:restaurant]
    @table      = @ctx[:tables].first
    @product1   = @ctx[:products].first   # Bandeja Paisa  $28.000
    @product2   = @ctx[:products].last    # Ajiaco         $22.000
  end

  # ── Validaciones ──────────────────────────────────────────────

  test "un pedido válido se crea correctamente" do
    order = create_order(@restaurant, @table)
    assert order.persisted?
    assert_equal "open", order.status
    assert order.opened_at.present?
  end

  test "un pedido requiere table_id" do
    order = Order.new(restaurant: @restaurant, status: "open", opened_at: Time.current)
    assert_not order.valid?
    assert order.errors[:table_id].any?
  end

  test "un pedido requiere restaurant_id" do
    order = Order.new(table: @table, status: "open", opened_at: Time.current)
    assert_not order.valid?
  end

  # ── Cálculo de totales ────────────────────────────────────────

  test "el total se calcula automáticamente al agregar items" do
    order = create_order(@restaurant, @table)
    create_order_item(order, @product1, quantity: 2)  # 2 × 28.000 = 56.000
    create_order_item(order, @product2, quantity: 1)  # 1 × 22.000 = 22.000

    order.reload
    assert_equal 78_000, order.subtotal
    assert_equal (78_000 * 0.19).round(2), order.tax
    assert_equal order.subtotal + order.tax, order.total
  end

  test "el subtotal es 0 para un pedido sin items" do
    order = create_order(@restaurant, @table)
    assert_equal 0, order.subtotal
    assert_equal 0, order.total
  end

  # ── Snapshot de precios ───────────────────────────────────────

  test "el item conserva el precio original aunque el producto cambie de precio" do
    order = create_order(@restaurant, @table)
    item  = create_order_item(order, @product1, quantity: 1)

    precio_original = @product1.price

    # Simular cambio de precio desde el Cloud
    @product1.update_columns(price: 35_000)

    item.reload
    assert_equal precio_original, item.unit_price,
      "El item debe conservar el precio al momento del pedido"
  end

  test "el item conserva el nombre original aunque el producto cambie de nombre" do
    order = create_order(@restaurant, @table)
    item  = create_order_item(order, @product1)

    nombre_original = @product1.name
    @product1.update_columns(name: "Bandeja Especial")

    item.reload
    assert_equal nombre_original, item.product_name
  end

  # ── Transiciones de estado ────────────────────────────────────

  test "un pedido abierto puede pasar a in_progress" do
    order = create_order(@restaurant, @table)
    order.start!
    assert_equal "in_progress", order.reload.status
  end

  test "cerrar un pedido registra closed_at y libera la mesa" do
    order = create_order(@restaurant, @table)
    @table.update!(status: "occupied")

    order.close!

    assert_equal "closed", order.reload.status
    assert order.reload.closed_at.present?
    assert_equal "available", @table.reload.status
  end

  test "cancelar un pedido libera la mesa" do
    order = create_order(@restaurant, @table)
    @table.update!(status: "occupied")

    order.cancel!

    assert_equal "cancelled", order.reload.status
    assert_equal "available", @table.reload.status
  end

  test "duration_minutes calcula el tiempo del pedido correctamente" do
    order = create_order(@restaurant, @table)
    order.update_columns(
      opened_at: 45.minutes.ago,
      closed_at: Time.current,
      status:    "closed"
    )

    assert_in_delta 45, order.duration_minutes, 1
  end

  # ── Scopes ────────────────────────────────────────────────────

  test "scope active retorna solo pedidos no cerrados ni cancelados" do
    open_order      = create_order(@restaurant, @table)
    table2          = @ctx[:tables].last
    cancelled_order = create_order(@restaurant, table2)
    cancelled_order.update_columns(status: "cancelled")

    active = @restaurant.orders.active
    assert_includes active, open_order
    assert_not_includes active, cancelled_order
  end

  test "scope today retorna solo pedidos de hoy" do
    order_hoy  = create_order(@restaurant, @table)
    table2     = @ctx[:tables].last
    order_ayer = create_order(@restaurant, table2)
    order_ayer.update_columns(opened_at: 25.hours.ago)

    today_orders = @restaurant.orders.today
    assert_includes today_orders, order_hoy
    assert_not_includes today_orders, order_ayer
  end
end
