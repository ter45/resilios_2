# ══════════════════════════════════════════════════════════════════
#  ResiliOS — Contrato API de Sincronización
#  Base URL: https://app.resilios.com/api/v1/sync
#
#  Autenticación: Bearer token del nodo Edge
#  Header: Authorization: Bearer <node_token>
#          X-Node-ID: <node_ulid>
#          X-Node-Version: <edge_version>
#          Content-Type: application/json
# ══════════════════════════════════════════════════════════════════


# ╔══════════════════════════════════════════════════════════════╗
# ║  POST /api/v1/sync/operations                               ║
# ║  Enviar batch de operaciones pendientes al Cloud            ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Reglas:
# - Máximo 500 operaciones por request
# - Operaciones deben estar en orden cronológico (ULID ordering)
# - Si una operación ya fue procesada (duplicate ULID), se ignora silenciosamente
# - El servidor procesa todas las operaciones aunque algunas fallen
#
# REQUEST:
# POST /api/v1/sync/operations
# {
#   "node_id": "01HX5Y...",
#   "restaurant_id": "01HX5Z...",
#   "operations": [
#     {
#       "id": "01HX6A...",           // ULID de la SyncOperation en el Edge
#       "operation_type": "create",  // create | update | delete
#       "entity_type": "Order",
#       "entity_id": "01HX6B...",    // ULID de la entidad
#       "created_at": "2026-04-01T14:32:00.000Z",
#       "payload": { ... }           // Objeto completo de la entidad
#     }
#   ]
# }
#
# RESPONSE 200 OK:
# {
#   "processed": 47,
#   "ignored": 3,         // Duplicados ya procesados anteriormente
#   "rejected": 0,
#   "conflicts_resolved": 1,
#   "results": [
#     {
#       "operation_id": "01HX6A...",
#       "result": "applied",         // applied | ignored | conflict_resolved | rejected
#       "conflict_detail": null
#     },
#     {
#       "operation_id": "01HX6C...",
#       "result": "conflict_resolved",
#       "conflict_detail": {
#         "policy": "last_write_wins",
#         "winning_version": "cloud",
#         "reason": "cloud updated_at is newer"
#       }
#     }
#   ]
# }
#
# RESPONSE 401 Unauthorized: token inválido o expirado
# RESPONSE 422 Unprocessable: más de 500 operaciones, formato inválido
# RESPONSE 429 Too Many Requests: rate limit excedido (10 req/min por nodo)

# ──────────────────────────────────────────────────────────────────
# PAYLOADS POR ENTIDAD
# ──────────────────────────────────────────────────────────────────

# Order — create / update
ORDER_PAYLOAD = {
  "id" => "01HX6B...",                    # ULID
  "restaurant_id" => "01HX5Z...",
  "table_id" => "01HX6D...",
  "table_label" => "Mesa 5",              # Snapshot para Cloud
  "status" => "closed",
  "waiter_name" => "Carlos",
  "subtotal" => "45000.00",
  "tax" => "8550.00",
  "total" => "53550.00",
  "notes" => nil,
  "was_offline" => true,                  # Si se creó sin internet
  "opened_at" => "2026-04-01T14:30:00.000Z",
  "closed_at" => "2026-04-01T15:10:00.000Z",
  "created_at" => "2026-04-01T14:30:00.000Z",
  "updated_at" => "2026-04-01T15:10:00.000Z"
}

# OrderItem — create / update
ORDER_ITEM_PAYLOAD = {
  "id" => "01HX6E...",
  "order_id" => "01HX6B...",
  "product_id" => "01HX6F...",
  "product_name" => "Bandeja Paisa",      # Snapshot del nombre
  "unit_price" => "28000.00",             # Snapshot del precio
  "quantity" => 2,
  "subtotal" => "56000.00",
  "notes" => "Sin chicharrón",
  "status" => "served",
  "created_at" => "2026-04-01T14:32:00.000Z",
  "updated_at" => "2026-04-01T14:45:00.000Z"
}

# Product — update (solo sync descendente Cloud -> Edge normalmente)
PRODUCT_PAYLOAD = {
  "id" => "01HX6F...",
  "restaurant_id" => "01HX5Z...",
  "category_id" => "01HX6G...",
  "name" => "Bandeja Paisa",
  "price" => "28000.00",
  "available" => true,
  "position" => 1,
  "updated_at" => "2026-04-01T10:00:00.000Z"
}


# ╔══════════════════════════════════════════════════════════════╗
# ║  GET /api/v1/sync/status                                    ║
# ║  El Edge consulta el estado del Cloud y recibe cambios      ║
# ║  descendentes (menú, configuración)                         ║
# ╚══════════════════════════════════════════════════════════════╝
#
# RESPONSE 200 OK:
# {
#   "node_id": "01HX5Y...",
#   "server_time": "2026-04-01T15:30:00.000Z",
#   "node_status": "healthy",
#   "pending_downstream": {
#     "products": [           // Productos actualizados en Cloud desde último sync
#       { ...product_payload... }
#     ],
#     "categories": [
#       { ...category_payload... }
#     ],
#     "restaurant_settings": {
#       "name": "La Fogata",
#       "timezone": "America/Bogota"
#     }
#   },
#   "last_sync_acknowledged": "01HX6A..."  // Último operation_id procesado por Cloud
# }


# ╔══════════════════════════════════════════════════════════════╗
# ║  POST /api/v1/sync/heartbeat                                ║
# ║  El Edge reporta su estado de salud cada 30 segundos        ║
# ╚══════════════════════════════════════════════════════════════╝
#
# REQUEST:
# {
#   "node_id": "01HX5Y...",
#   "version": "1.2.0",
#   "pending_operations": 0,
#   "telemetry": {
#     "disk_free_mb": 12480,
#     "memory_free_mb": 890,
#     "db_size_mb": 45,
#     "uptime_seconds": 86400
#   }
# }
#
# RESPONSE 200 OK:
# {
#   "acknowledged": true,
#   "server_time": "2026-04-01T15:30:00.000Z"
# }


# ╔══════════════════════════════════════════════════════════════╗
# ║  POST /api/v1/sync/link                                     ║
# ║  Vincula un nodo Edge recién instalado via token QR         ║
# ╚══════════════════════════════════════════════════════════════╝
#
# REQUEST:
# {
#   "link_token": "eyJ...",   // Token de un solo uso generado en el Cloud
#   "node_version": "1.0.0",
#   "hostname": "resilios-local"
# }
#
# RESPONSE 200 OK:
# {
#   "node_id": "01HX5Y...",
#   "restaurant_id": "01HX5Z...",
#   "node_token": "nt_...",    // Token permanente para requests futuros
#   "restaurant": {
#     "id": "01HX5Z...",
#     "name": "La Fogata",
#     "timezone": "America/Bogota"
#   },
#   "initial_data": {          // Seed de datos para el Edge recién instalado
#     "categories": [ ... ],
#     "products": [ ... ],
#     "tables": [ ... ]
#   }
# }
#
# RESPONSE 401: token inválido
# RESPONSE 410: token expirado o ya usado


# ──────────────────────────────────────────────────────────────────
# POLÍTICAS DE RESOLUCIÓN DE CONFLICTOS
# ──────────────────────────────────────────────────────────────────
#
# Cuando el Sync Engine detecta que la misma entidad fue modificada
# tanto en el Edge (offline) como en el Cloud, aplica:
#
# | Entidad     | Política               | Razón                              |
# |-------------|------------------------|------------------------------------|
# | Order       | last_write_wins        | El más reciente tiene más contexto |
# | OrderItem   | merge                  | Se unen items de ambas versiones   |
# | Product     | server_authoritative   | Cloud es fuente de verdad del menú |
# | Category    | server_authoritative   | Cloud es fuente de verdad del menú |
# | Table       | server_authoritative   | Estado de mesa lo controla el Edge |
#
# Todos los conflictos se registran en sync_logs.conflict_detail.
# El dashboard del Cloud muestra conflictos resueltos por restaurante.


# ──────────────────────────────────────────────────────────────────
# IMPLEMENTACIÓN: SyncAgent (edge/app/services/sync_agent.rb)
# ──────────────────────────────────────────────────────────────────

SYNC_AGENT_PSEUDOCODE = <<~RUBY
  class SyncAgent
    BATCH_SIZE       = 100
    HEARTBEAT_EVERY  = 30   # segundos
    RETRY_BACKOFF    = [5, 15, 60, 300]  # segundos entre reintentos

    def self.run_forever
      loop do
        begin
          new.run_cycle
        rescue => e
          Rails.logger.error "[SyncAgent] Error: #{e.message}"
        end
        sleep ENV.fetch("SYNC_INTERVAL_SECONDS", 30).to_i
      end
    end

    def run_cycle
      send_heartbeat
      return unless internet_available?

      # 1. Subir operaciones pendientes al Cloud
      pending = SyncOperation.where(status: "pending")
                             .order(:created_at)
                             .limit(BATCH_SIZE)

      if pending.any?
        response = CloudApi.post("/sync/operations", {
          node_id: node_id,
          restaurant_id: restaurant_id,
          operations: pending.map(&:to_api_payload)
        })

        process_sync_response(pending, response)
      end

      # 2. Recibir cambios descendentes del Cloud (menú, config)
      downstream = CloudApi.get("/sync/status")
      apply_downstream_changes(downstream["pending_downstream"])
    end

    private

    def internet_available?
      # Intento de conexión al Cloud con timeout de 3 segundos
      CloudApi.health_check(timeout: 3)
    rescue
      false
    end

    def process_sync_response(operations, response)
      ActiveRecord::Base.transaction do
        response["results"].each do |result|
          op = operations.find { |o| o.id == result["operation_id"] }
          next unless op

          case result["result"]
          when "applied", "ignored", "conflict_resolved"
            op.update!(status: "synced", synced_at: Time.current)
          when "rejected"
            op.update!(
              status: "failed",
              last_error: result["conflict_detail"].to_json,
              retry_count: op.retry_count + 1
            )
          end
        end
      end
    end
  end
RUBY
