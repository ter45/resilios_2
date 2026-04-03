# ══════════════════════════════════════════════════════════════════
#  edge/test/models/syncable_test.rb
#
#  Tests unitarios del Outbox Pattern (Concern Syncable).
#  Verifican que TODA mutación genera su SyncOperation
#  y que el log es verdaderamente inmutable.
# ══════════════════════════════════════════════════════════════════

require "test_helper"

class SyncableTest < ActiveSupport::TestCase

  setup do
    @ctx = setup_full_restaurant
    @restaurant = @ctx[:restaurant]
    @table      = @ctx[:tables].first
    @product    = @ctx[:products].first
  end

  # ── Generación automática de SyncOperations ───────────────────

  test "crear un pedido genera una SyncOperation de tipo create" do
    assert_difference "SyncOperation.count", 1 do
      create_order(@restaurant, @table)
    end

    op = SyncOperation.last
    assert_equal "create",  op.operation_type
    assert_equal "Order",   op.entity_type
    assert_equal "pending", op.status
    assert op.payload.present?
  end

  test "actualizar un pedido genera una SyncOperation de tipo update" do
    order = create_order(@restaurant, @table)

    assert_difference "SyncOperation.count", 1 do
      order.update!(waiter_name: "María")
    end

    op = SyncOperation.last
    assert_equal "update", op.operation_type
    assert_equal "Order",  op.entity_type
  end

  test "cancelar un pedido genera una SyncOperation de tipo delete" do
    order = create_order(@restaurant, @table)

    assert_difference "SyncOperation.count", 1 do
      order.cancel!
    end

    op = SyncOperation.last
    assert_equal "delete", op.operation_type
  end

  test "crear un order item genera su propia SyncOperation" do
    order = create_order(@restaurant, @table)

    assert_difference "SyncOperation.count", 1 do
      create_order_item(order, @product)
    end

    op = SyncOperation.last
    assert_equal "create",     op.operation_type
    assert_equal "OrderItem",  op.entity_type
  end

  test "actualizar sync_status no genera SyncOperation adicional" do
    order = create_order(@restaurant, @table)
    count_before = SyncOperation.count

    # Simular lo que hace el SyncAgent al marcar como sincronizado
    order.update_columns(sync_status: "synced", synced_at: Time.current)

    assert_equal count_before, SyncOperation.count,
      "Actualizar campos de sync no debe generar nueva SyncOperation"
  end

  # ── Transaccionalidad del Outbox Pattern ─────────────────────

  test "si falla la creación del pedido no queda SyncOperation huérfana" do
    initial_ops = SyncOperation.count

    assert_raises(ActiveRecord::RecordInvalid) do
      # Forzar fallo: table_id inválido
      @restaurant.orders.create!(
        table_id:   "id-inexistente",
        waiter_name: "Carlos",
        status:     "open",
        opened_at:  Time.current
      )
    end

    assert_equal initial_ops, SyncOperation.count,
      "Un pedido fallido no debe dejar SyncOperations en la cola"
  end

  test "si falla la SyncOperation se hace rollback del pedido completo" do
    initial_orders = Order.count

    # Forzar fallo en SyncOperation (payload nil)
    SyncOperation.stub(:create!, ->(_) { raise ActiveRecord::Rollback }) do
      assert_raises(ActiveRecord::Rollback) do
        create_order(@restaurant, @table)
      end
    end

    assert_equal initial_orders, Order.count,
      "Si falla la SyncOperation, el pedido no debe quedar en la DB"
  end

  # ── Inmutabilidad del Operation Log ──────────────────────────

  test "no se puede modificar el payload de una SyncOperation existente" do
    create_order(@restaurant, @table)
    op = SyncOperation.last

    result = op.update(payload: '{"hacked": true}')

    assert_equal false, result
    assert op.errors[:base].any? { |e| e.include?("immutable") }
    assert_not_equal '{"hacked": true}', op.reload.payload
  end

  test "no se puede modificar el operation_type de una SyncOperation" do
    create_order(@restaurant, @table)
    op = SyncOperation.last

    result = op.update(operation_type: "delete")

    assert_equal false, result
    assert_equal "create", op.reload.operation_type
  end

  test "no se puede modificar el entity_type de una SyncOperation" do
    create_order(@restaurant, @table)
    op = SyncOperation.last

    result = op.update(entity_type: "Product")

    assert_equal false, result
    assert_equal "Order", op.reload.entity_type
  end

  # ── Campos sí modificables por el SyncAgent ──────────────────

  test "el SyncAgent puede marcar una operación como synced" do
    create_order(@restaurant, @table)
    op = SyncOperation.last

    op.mark_synced!

    assert_equal "synced", op.reload.status
    assert op.reload.synced_at.present?
  end

  test "mark_failed incrementa retry_count y registra el error" do
    create_order(@restaurant, @table)
    op = SyncOperation.last

    op.mark_failed!("Connection timeout")

    assert_equal 1, op.reload.retry_count
    assert_equal "Connection timeout", op.reload.last_error
  end

  test "después de MAX_RETRIES la operación queda como failed permanentemente" do
    create_order(@restaurant, @table)
    op = SyncOperation.last
    op.update_columns(retry_count: SyncOperation::MAX_RETRIES)

    op.mark_failed!("Persistent error")

    assert_equal "failed", op.reload.status
  end

  # ── ULIDs ────────────────────────────────────────────────────

  test "las SyncOperations tienen IDs ULID válidos" do
    create_order(@restaurant, @table)
    op = SyncOperation.last

    assert_equal 26, op.id.length
    assert_match /\A[0-9A-Z]{26}\z/, op.id
  end

  test "los IDs ULID están ordenados cronológicamente" do
    order = create_order(@restaurant, @table)
    sleep 0.01
    create_order_item(order, @product)

    ops = SyncOperation.order(:created_at).last(2)
    assert ops.first.id < ops.last.id,
      "Los ULIDs deben ordenarse cronológicamente"
  end
end
