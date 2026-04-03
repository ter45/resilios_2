# ══════════════════════════════════════════════════════════════════
#  ResiliOS Cloud — Migraciones PostgreSQL
#  Archivo: cloud/db/migrate/
#  Ejecutar: bundle exec rails db:migrate
# ══════════════════════════════════════════════════════════════════

# ── 001 — Habilitar extensiones PostgreSQL ───────────────────────
# cloud/db/migrate/20260401000001_enable_extensions.rb

class EnableExtensions < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto"   # gen_random_uuid() como fallback
    enable_extension "pg_trgm"    # Búsqueda full-text en productos y pedidos
    enable_extension "btree_gin"  # Índices GIN para JSONB
  end
end

# ── 002 — Cuentas (multi-tenant raíz) ───────────────────────────
# cloud/db/migrate/20260401000002_create_accounts.rb

class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts, id: false do |t|
      t.string   :id,                   null: false   # ULID
      t.string   :name,                 null: false
      t.string   :email,                null: false
      t.string   :password_digest,      null: false
      t.string   :stripe_customer_id
      t.string   :plan,                 default: "trial"
                                                      # trial | starter | pro | enterprise
      t.string   :status,               default: "active"
                                                      # active | suspended | cancelled
      t.string   :timezone,             default: "America/Bogota"
      t.jsonb    :metadata,             default: {}
      t.datetime :trial_ends_at
      t.datetime :created_at,           null: false
      t.datetime :updated_at,           null: false
    end

    add_index :accounts, :id, unique: true
    add_index :accounts, :email, unique: true
    add_index :accounts, :stripe_customer_id, where: "stripe_customer_id IS NOT NULL"
    add_index :accounts, :status
  end
end

# ── 003 — Suscripciones Stripe ───────────────────────────────────
# cloud/db/migrate/20260401000003_create_subscriptions.rb

class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions, id: false do |t|
      t.string   :id,                         null: false   # ULID
      t.string   :account_id,                 null: false
      t.string   :stripe_subscription_id,     null: false
      t.string   :stripe_price_id
      t.string   :plan,                       null: false
      t.string   :status,                     null: false
                                                            # active | past_due | cancelled | trialing
      t.integer  :orders_per_month_limit,     default: 500
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :cancelled_at
      t.datetime :created_at,                 null: false
      t.datetime :updated_at,                 null: false
    end

    add_index :subscriptions, :account_id
    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, :status

    add_foreign_key :subscriptions, :accounts, column: :account_id, primary_key: :id
  end
end

# ── 004 — Restaurantes (pertenecen a una cuenta) ─────────────────
# cloud/db/migrate/20260401000004_create_restaurants.rb

class CreateRestaurants < ActiveRecord::Migration[8.0]
  def change
    create_table :restaurants, id: false do |t|
      t.string   :id,             null: false   # ULID — mismo ID que en el Edge
      t.string   :account_id,     null: false
      t.string   :name,           null: false
      t.string   :timezone,       default: "America/Bogota"
      t.string   :address
      t.string   :phone
      t.string   :currency,       default: "COP"
      t.jsonb    :settings,       default: {}
      t.boolean  :active,         default: true
      t.datetime :created_at,     null: false
      t.datetime :updated_at,     null: false
    end

    add_index :restaurants, :id, unique: true
    add_index :restaurants, :account_id
    add_index :restaurants, [:account_id, :active]

    add_foreign_key :restaurants, :accounts, column: :account_id, primary_key: :id
  end
end

# ── 005 — Nodos Edge registrados ─────────────────────────────────
# cloud/db/migrate/20260401000005_create_edge_nodes.rb

class CreateEdgeNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :edge_nodes, id: false do |t|
      t.string   :id,                   null: false   # ULID
      t.string   :account_id,           null: false
      t.string   :restaurant_id,        null: false
      t.string   :node_token_hash,      null: false   # HMAC del token — nunca texto plano
      t.string   :version                             # Versión del software Edge
      t.string   :ip_address
      t.string   :hostname
      t.jsonb    :telemetry,            default: {}   # CPU, disco, RAM, pending_sync_count
      t.string   :sync_status,          default: "unknown"
                                                      # healthy | degraded | offline | unknown
      t.integer  :pending_operations,   default: 0
      t.datetime :last_seen_at
      t.datetime :last_sync_at
      t.datetime :created_at,           null: false
      t.datetime :updated_at,           null: false
    end

    add_index :edge_nodes, :id, unique: true
    add_index :edge_nodes, :restaurant_id
    add_index :edge_nodes, :node_token_hash, unique: true
    add_index :edge_nodes, :last_seen_at
    add_index :edge_nodes, :sync_status

    add_foreign_key :edge_nodes, :restaurants, column: :restaurant_id, primary_key: :id
  end
end

# ── 006 — Pedidos centralizados ──────────────────────────────────
# cloud/db/migrate/20260401000006_create_orders.rb

class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders, id: false do |t|
      t.string   :id,             null: false   # ULID del Edge (preservado)
      t.string   :restaurant_id,  null: false
      t.string   :edge_node_id                  # Nodo que originó el pedido
      t.string   :table_label,    null: false   # Snapshot del número/nombre de mesa
      t.string   :status,         null: false, default: "open"
      t.string   :waiter_name
      t.decimal  :subtotal,       precision: 10, scale: 2, default: 0
      t.decimal  :tax,            precision: 10, scale: 2, default: 0
      t.decimal  :total,          precision: 10, scale: 2, default: 0
      t.text     :notes
      t.string   :origin,         default: "edge"
                                                # edge | cloud | api
      t.boolean  :was_offline,    default: false  # True si se creó sin internet
      t.datetime :opened_at,      null: false
      t.datetime :closed_at
      t.datetime :synced_at,      null: false   # Cuándo llegó al Cloud
      t.datetime :created_at,     null: false
      t.datetime :updated_at,     null: false
    end

    add_index :orders, :id, unique: true
    add_index :orders, :restaurant_id
    add_index :orders, :edge_node_id
    add_index :orders, :status
    add_index :orders, :opened_at
    add_index :orders, [:restaurant_id, :opened_at]
    add_index :orders, [:restaurant_id, :was_offline]   # Para analytics offline vs online

    add_foreign_key :orders, :restaurants, column: :restaurant_id, primary_key: :id
  end
end

# ── 007 — Items de pedido centralizados ──────────────────────────
# cloud/db/migrate/20260401000007_create_order_items.rb

class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items, id: false do |t|
      t.string   :id,             null: false   # ULID del Edge (preservado)
      t.string   :order_id,       null: false
      t.string   :product_name,   null: false   # Snapshot
      t.decimal  :unit_price,     null: false, precision: 10, scale: 2
      t.integer  :quantity,       null: false, default: 1
      t.decimal  :subtotal,       precision: 10, scale: 2
      t.text     :notes
      t.string   :status,         default: "served"
      t.datetime :synced_at,      null: false
      t.datetime :created_at,     null: false
      t.datetime :updated_at,     null: false
    end

    add_index :order_items, :id, unique: true
    add_index :order_items, :order_id
    add_index :order_items, :product_name   # Para analytics de productos más vendidos

    add_foreign_key :order_items, :orders, column: :order_id, primary_key: :id
  end
end

# ── 008 — Sync Log (registro inmutable de sincronizaciones) ──────
# cloud/db/migrate/20260401000008_create_sync_log.rb
#
# Diferencia con Edge sync_operations:
# - Edge: cola de trabajo pendiente (se marca como synced)
# - Cloud sync_log: registro histórico inmutable de todo lo recibido

class CreateSyncLog < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_logs, id: false do |t|
      t.string   :id,               null: false   # ULID del Cloud
      t.string   :edge_node_id,     null: false
      t.string   :restaurant_id,    null: false
      t.string   :operation_id,     null: false   # ULID de la SyncOperation del Edge
      t.string   :operation_type,   null: false   # create | update | delete
      t.string   :entity_type,      null: false
      t.string   :entity_id,        null: false
      t.jsonb    :payload,          null: false   # Payload original recibido
      t.string   :result,           null: false
                                                  # applied | ignored | conflict_resolved | rejected
      t.jsonb    :conflict_detail                 # Detalle si hubo conflicto
      t.integer  :processing_ms                   # Tiempo de procesamiento
      t.datetime :received_at,      null: false
      t.datetime :processed_at,     null: false
    end

    add_index :sync_logs, :id, unique: true
    add_index :sync_logs, :edge_node_id
    add_index :sync_logs, :operation_id, unique: true   # Idempotencia: mismo operation_id = ignorado
    add_index :sync_logs, [:edge_node_id, :received_at]
    add_index :sync_logs, :result
    add_index :sync_logs, :entity_id

    add_foreign_key :sync_logs, :edge_nodes, column: :edge_node_id, primary_key: :id
  end
end
