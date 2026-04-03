# ══════════════════════════════════════════════════════════════════
#  edge/app/services/sync_agent.rb
#
#  Proceso en background que sincroniza la cola de SyncOperations
#  con el Cloud cuando hay conexión a internet disponible.
#
#  Ejecutado por el contenedor sync_agent en Docker:
#    bundle exec rails runner "SyncAgent.run_forever"
# ══════════════════════════════════════════════════════════════════

class SyncAgent
  BATCH_SIZE      = 100
  RETRY_BACKOFF   = [5, 15, 60, 300, 900].freeze  # segundos
  MAX_LAG_ALERT   = 7200                            # 2 horas en segundos

  # ── Punto de entrada para el contenedor Docker ────────────────

  def self.run_forever
    Rails.logger.info "[SyncAgent] Iniciando — intervalo: #{interval}s"

    loop do
      new.run_cycle
    rescue => e
      Rails.logger.error "[SyncAgent] Error en ciclo: #{e.class} — #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    ensure
      sleep interval
    end
  end

  def self.interval
    ENV.fetch("SYNC_INTERVAL_SECONDS", "30").to_i
  end

  # ── Ciclo principal ───────────────────────────────────────────

  def run_cycle
    update_connectivity_status

    send_heartbeat

    return unless online?

    upload_pending_operations
    download_upstream_changes
    check_lag_alert
  end

  # ── Estado de conectividad ────────────────────────────────────

  def online?
    @online
  end

  # ── Upload: Edge → Cloud ──────────────────────────────────────

  def upload_pending_operations
    pending = SyncOperation.for_batch(BATCH_SIZE).to_a
    return if pending.empty?

    log "Enviando #{pending.size} operaciones al Cloud..."

    # Marcar como procesando (evita doble envío)
    SyncOperation.where(id: pending.map(&:id))
                 .update_all(status: "processing")

    response = cloud_api.post("/sync/operations", {
      node_id:       node_id,
      restaurant_id: restaurant_id,
      operations:    pending.map(&:to_api_payload)
    })

    process_upload_response(pending, response)
    update_last_sync

    log "Sync completado: #{response['processed']} aplicadas, #{response['ignored']} ignoradas"

  rescue CloudApi::NetworkError => e
    # Revertir a pending si hubo error de red
    SyncOperation.where(id: pending.map(&:id), status: "processing")
                 .update_all(status: "pending")
    log "Error de red durante upload: #{e.message}", level: :warn

  rescue CloudApi::AuthError => e
    log "Error de autenticación: #{e.message}. Revisa RESILIOS_NODE_TOKEN.", level: :error
  end

  # ── Download: Cloud → Edge (menú, configuración) ─────────────

  def download_upstream_changes
    response = cloud_api.get("/sync/status")
    downstream = response["pending_downstream"]
    return if downstream.blank?

    ActiveRecord::Base.transaction do
      apply_product_updates(downstream["products"])
      apply_category_updates(downstream["categories"])
      apply_restaurant_settings(downstream["restaurant_settings"])
    end

    log "Cambios descendentes aplicados: #{downstream.values.flatten.size} registros"

  rescue CloudApi::NetworkError => e
    log "Error al descargar cambios: #{e.message}", level: :warn
  end

  private

  # ── Procesamiento de respuestas ───────────────────────────────

  def process_upload_response(operations, response)
    ops_by_id = operations.index_by(&:id)

    response["results"].each do |result|
      op = ops_by_id[result["operation_id"]]
      next unless op

      case result["result"]
      when "applied", "ignored", "conflict_resolved"
        op.mark_synced!
      when "rejected"
        error_detail = result.dig("conflict_detail")&.to_json || "rejected by server"
        op.mark_failed!(error_detail)
        log "Operación rechazada: #{op.entity_type}##{op.entity_id} — #{error_detail}", level: :warn
      end
    end
  end

  # ── Cambios descendentes ──────────────────────────────────────

  def apply_product_updates(products)
    return if products.blank?

    products.each do |data|
      product = Product.find_or_initialize_by(id: data["id"])
      product.assign_attributes(
        restaurant_id: data["restaurant_id"],
        category_id:   data["category_id"],
        name:          data["name"],
        price:         data["price"],
        available:     data["available"],
        position:      data["position"],
        synced_at:     Time.current
      )
      product.save!
    end
  end

  def apply_category_updates(categories)
    return if categories.blank?

    categories.each do |data|
      category = Category.find_or_initialize_by(id: data["id"])
      category.assign_attributes(
        restaurant_id: data["restaurant_id"],
        name:          data["name"],
        position:      data["position"],
        active:        data["active"],
        synced_at:     Time.current
      )
      category.save!
    end
  end

  def apply_restaurant_settings(settings)
    return if settings.blank?

    Restaurant.first&.update!(
      name:     settings["name"],
      timezone: settings["timezone"]
    )
  end

  # ── Heartbeat ─────────────────────────────────────────────────

  def send_heartbeat
    cloud_api.post("/sync/heartbeat", {
      node_id:            node_id,
      version:            Edge::VERSION,
      pending_operations: SyncOperation.pending_count,
      telemetry: {
        disk_free_mb:    disk_free_mb,
        db_size_mb:      db_size_mb,
        uptime_seconds:  process_uptime,
      }
    })
  rescue
    # El heartbeat nunca debe detener el ciclo principal
  end

  # ── Conectividad ──────────────────────────────────────────────

  def update_connectivity_status
    @online = cloud_api.health_check(timeout: 3)
    broadcast_connectivity_status(@online ? "online" : "offline")
  rescue
    @online = false
    broadcast_connectivity_status("offline")
  end

  def broadcast_connectivity_status(status)
    # Notifica a la PWA via ActionCable local
    ActionCable.server.broadcast("connectivity", { status: status })
  rescue
    nil
  end

  # ── Alerta de lag ─────────────────────────────────────────────

  def check_lag_alert
    lag = SyncOperation.max_lag_seconds
    if lag > MAX_LAG_ALERT
      log "ALERTA: Hay operaciones pendientes hace #{lag / 3600}h", level: :warn
    end
  end

  # ── Telemetría del sistema ────────────────────────────────────

  def disk_free_mb
    stat = Sys::Filesystem.stat("/")
    (stat.bytes_available / 1_048_576).to_i
  rescue
    nil
  end

  def db_size_mb
    db_path = Rails.root.join("storage", "resilios_edge.sqlite3")
    (File.size(db_path) / 1_048_576.0).round(1)
  rescue
    nil
  end

  def process_uptime
    (Time.current - $process_start_time).to_i
  rescue
    nil
  end

  # ── Helpers ───────────────────────────────────────────────────

  def update_last_sync
    Restaurant.first&.update_column(:last_sync_at, Time.current)
  end

  def node_id
    ENV.fetch("RESILIOS_NODE_ID")
  end

  def restaurant_id
    Restaurant.first&.id
  end

  def cloud_api
    @cloud_api ||= CloudApi.new(
      base_url:   ENV.fetch("RESILIOS_CLOUD_URL"),
      node_token: ENV.fetch("RESILIOS_NODE_TOKEN")
    )
  end

  def log(msg, level: :info)
    Rails.logger.send(level, "[SyncAgent] #{msg}")
  end
end
