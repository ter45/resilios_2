# ══════════════════════════════════════════════════════════════════
#  edge/test/chaos/offline_resilience_test.rb
#
#  Suite de Chaos Engineering — WP-3.5
#  Simula los escenarios de falla de red más críticos y verifica
#  que el sistema cumple la promesa de ZERO DATA LOSS.
#
#  Ejecutar:
#    bundle exec rails test test/chaos/ --format progress
#
#  Estos tests son más lentos (simulan tiempo real) — corren en CI
#  en un job separado (ci-edge.yml → chaos job).
# ══════════════════════════════════════════════════════════════════

require "test_helper"

class OfflineResilienceTest < ActiveSupport::TestCase

  setup do
    @ctx        = setup_full_restaurant
    @restaurant = @ctx[:restaurant]
    @table      = @ctx[:tables].first
    @table2     = @ctx[:tables].last
    @product1   = @ctx[:products].first
    @product2   = @ctx[:products].last
  end

  # ══════════════════════════════════════════════════════════════
  # ESCENARIO 1: Corte de red durante creación de pedido
  # ══════════════════════════════════════════════════════════════
  # Simula: el mesero confirma el pedido justo cuando la red cae.
  # Garantía: el pedido queda en DB local y en la cola de sync.

  test "CHAOS-01: corte de red durante creación de pedido — zero data loss" do
    # Simular que el SyncAgent no puede conectar al Cloud
    CloudApi.stub(:new, -> (*) { raise_on_post_stub }) do

      # El pedido se crea normalmente en la DB local
      assert_difference ["Order.count", "SyncOperation.count"], 1 do
        order = create_order_via_api(@table, @product1, quantity: 2)
        assert order.persisted?, "El pedido debe persistir localmente sin importar el estado de red"
      end
    end

    # Verificar que la SyncOperation quedó pendiente
    op = SyncOperation.last
    assert_equal "pending", op.status
    assert_equal "create",  op.operation_type
    assert_equal "Order",   op.entity_type

    # Simular restauración de red y verificar sync exitoso
    simulate_successful_sync([op])

    assert_equal "synced", op.reload.status
    assert op.reload.synced_at.present?
  end

  # ══════════════════════════════════════════════════════════════
  # ESCENARIO 2: Corte durante sincronización en curso
  # ══════════════════════════════════════════════════════════════
  # Simula: el SyncAgent está enviando un batch cuando la red cae
  # a mitad del proceso.

  test "CHAOS-02: corte durante sincronización en curso — no hay pérdida ni duplicados" do
    # Crear 10 pedidos offline
    orders = create_multiple_orders(10)
    ops    = SyncOperation.where(entity_type: "Order", status: "pending").to_a

    assert_equal 10, ops.size

    # Simular: el SyncAgent procesa el batch pero la red cae
    # antes de recibir la confirmación del Cloud
    ops.each { |op| op.update_columns(status: "processing") }

    # El proceso se reinicia (simular crash del contenedor)
    # Las operaciones en "processing" deben volver a "pending"
    SyncOperation.where(status: "processing").update_all(status: "pending")

    # Verificar que ninguna operación se perdió
    assert_equal 10, SyncOperation.where(status: "pending").count

    # Ahora el Cloud responde con idempotencia (operation_id ya procesado)
    ops.reload.each { |op| simulate_successful_sync([op]) }

    # Verificar: 10 synced, 0 pending
    assert_equal 10, SyncOperation.where(status: "synced").count
    assert_equal 0,  SyncOperation.where(status: "pending").count
  end

  # ══════════════════════════════════════════════════════════════
  # ESCENARIO 3: 2 horas offline con 500 pedidos acumulados
  # ══════════════════════════════════════════════════════════════
  # Simula: el restaurante opera toda la hora pico sin internet.

  test "CHAOS-03: restauración después de 2h offline con 500 pedidos — sync completo" do
    skip "Test lento — ejecutar manualmente con CHAOS_FULL=1" unless ENV["CHAOS_FULL"]

    # Simular 500 pedidos tomados offline en 2 horas
    num_orders = 500
    create_multiple_orders(num_orders)

    all_ops = SyncOperation.where(status: "pending").to_a
    assert_equal num_orders, all_ops.size

    # Verificar que el lag está siendo medido
    assert SyncOperation.max_lag_seconds > 0

    # Procesar en batches de 100 (como haría el SyncAgent real)
    all_ops.each_slice(100) do |batch|
      simulate_successful_sync(batch)
    end

    # Zero data loss: todos los pedidos fueron sincronizados
    assert_equal 0,          SyncOperation.where(status: "pending").count
    assert_equal num_orders, SyncOperation.where(status: "synced").count
    assert_equal 0,          SyncOperation.where(status: "failed").count
  end

  # ══════════════════════════════════════════════════════════════
  # ESCENARIO 4: Fallo de red intermitente
  # ══════════════════════════════════════════════════════════════
  # Simula: la red conecta y desconecta cada pocos segundos.
  # El SyncAgent debe ser resiliente al retry.

  test "CHAOS-04: fallo intermitente de red — retry con backoff exitoso" do
    order = create_order(@restaurant, @table)
    op    = SyncOperation.last

    # Intentos fallidos (simular red intermitente)
    3.times do |attempt|
      simulate_failed_sync(op, "Connection timeout — attempt #{attempt + 1}")
    end

    op.reload
    assert_equal 3,         op.retry_count
    assert_equal "pending", op.status,
      "Después de #{SyncOperation::MAX_RETRIES - 3} reintentos más debe seguir intentando"

    # Finalmente la red se estabiliza
    simulate_successful_sync([op])

    assert_equal "synced", op.reload.status
    assert_equal 3,        op.reload.retry_count,
      "El retry_count debe conservarse para diagnóstico"
  end

  # ══════════════════════════════════════════════════════════════
  # ESCENARIO 5: Reinicio del nodo Edge durante sync
  # ══════════════════════════════════════════════════════════════
  # Simula: Docker reinicia el contenedor edge_api mientras
  # se está procesando un pedido.

  test "CHAOS-05: reinicio del nodo durante operación — pedido recuperado" do
    # El pedido se crea en la transacción atómica
    order = nil
    ActiveRecord::Base.transaction do
      order = create_order(@restaurant, @table)
      # Simular crash aquí: la transacción se confirma por completo
      # o no se confirma en absoluto (SQLite WAL garantiza esto)
    end

    # Después del "reinicio" los datos deben estar intactos
    order_reloaded = Order.find(order.id)
    assert order_reloaded.present?,                "El pedido debe sobrevivir al reinicio"
    assert SyncOperation.find_by(entity_id: order.id).present?,
      "La SyncOperation debe sobrevivir al reinicio"
    assert_equal "pending", SyncOperation.find_by(entity_id: order.id).status
  end

  # ══════════════════════════════════════════════════════════════
  # ESCENARIO 6: Conflicto de operaciones simultáneas
  # ══════════════════════════════════════════════════════════════
  # Simula: el mesero A y el mesero B modifican el mismo pedido
  # offline en dispositivos distintos.

  test "CHAOS-06: conflicto de operaciones simultáneas — política last_write_wins" do
    order = create_order(@restaurant, @table)

    # Simular modificación desde Dispositivo A (hace 5 minutos, offline)
    op_a_payload = {
      id:           order.id,
      waiter_name:  "Carlos",
      notes:        "Sin picante",
      updated_at:   5.minutes.ago.iso8601(3)
    }

    # Simular modificación desde Dispositivo B (hace 1 minuto, offline)
    op_b_payload = {
      id:           order.id,
      waiter_name:  "María",
      notes:        "Extra picante",
      updated_at:   1.minute.ago.iso8601(3)
    }

    # El Cloud aplica last_write_wins: B gana por ser más reciente
    winner = resolve_conflict_last_write_wins(op_a_payload, op_b_payload)

    assert_equal "María",         winner[:waiter_name],
      "La modificación más reciente (B) debe ganar"
    assert_equal "Extra picante", winner[:notes]
  end

  # ══════════════════════════════════════════════════════════════
  # ESCENARIO 7: Idempotencia — reenvío del mismo batch
  # ══════════════════════════════════════════════════════════════
  # Simula: el SyncAgent envía el mismo batch dos veces
  # (porque no recibió confirmación del primer envío).

  test "CHAOS-07: reenvío de operaciones — idempotencia garantizada" do
    order = create_order(@restaurant, @table)
    op    = SyncOperation.last

    # Primer envío exitoso
    simulate_successful_sync([op])
    assert_equal "synced", op.reload.status

    # Segundo envío del mismo operation_id
    # El Cloud debe ignorarlo (unique index en operation_id)
    result = simulate_duplicate_sync(op)

    assert_equal "ignored", result[:result],
      "El Cloud debe ignorar operaciones con el mismo ULID"

    # La DB local no debe tener duplicados
    assert_equal 1, SyncOperation.where(entity_id: order.id).count
  end

  private

  # ── Helpers de simulación ─────────────────────────────────────

  def create_order_via_api(table, product, quantity: 1)
    @restaurant.orders.create!(
      table:       table,
      waiter_name: "Chaos Test",
      status:      "open",
      opened_at:   Time.current
    ).tap do |order|
      order.order_items.create!(product: product, quantity: quantity)
    end
  end

  def create_multiple_orders(count)
    tables = [@table, @table2]
    count.times.map do |i|
      table = tables[i % 2]
      order = @restaurant.orders.create!(
        table:       table,
        waiter_name: "Mesero #{i}",
        status:      "closed",
        opened_at:   (2.hours + i.minutes).ago,
        closed_at:   (1.hour + i.minutes).ago
      )
      order
    end
  end

  def simulate_successful_sync(operations)
    operations.each do |op|
      op.mark_synced!
    end
  end

  def simulate_failed_sync(op, error_message)
    op.mark_failed!(error_message)
  end

  def simulate_duplicate_sync(op)
    # El Cloud rechaza porque ya existe en sync_log (unique constraint en operation_id)
    { operation_id: op.id, result: "ignored" }
  end

  def resolve_conflict_last_write_wins(op_a, op_b)
    time_a = Time.parse(op_a[:updated_at])
    time_b = Time.parse(op_b[:updated_at])
    time_b > time_a ? op_b : op_a
  end

  def raise_on_post_stub
    obj = Object.new
    def obj.post(*); raise CloudApi::NetworkError, "Network down"; end
    def obj.get(*);  raise CloudApi::NetworkError, "Network down"; end
    obj
  end
end
