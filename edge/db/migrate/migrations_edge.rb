# ══════════════════════════════════════════════════════════════════
#  ResiliOS Edge — Migraciones SQLite
#  Archivo: edge/db/migrate/
#  Ejecutar: bundle exec rails db:migrate
#
#  Convenciones:
#  - Todos los IDs son ULIDs (string, 26 chars)
#  - SQLite en WAL mode (configurado en database.yml)
#  - Toda mutación genera una SyncOperation (Outbox Pattern)
# ══════════════════════════════════════════════════════════════════

# ── 001 — Habilitar WAL mode y crear tabla base ──────────────────
# edge/db/migrate/20260401000001_enable_wal_and_create_restaurants.rb

class EnableWalAndCreateRestaurants < ActiveRecord::Migration[8.0]
  def up
    # WAL mode: permite lecturas concurrentes durante escrituras
    execute "PRAGMA journal_mode=WAL;"
    execute "PRAGMA synchronous=NORMAL;"
    execute "PRAGMA cache_size=-64000;"   # 64MB cache
    execute "PRAGMA foreign_keys=ON;"

    create_table :restaurants, id: false do |t|
      t.string  :id,                    null: false, primary_key: true  # ULID
      t.string  :name,                  null: false
      t.string  :cloud_restaurant_id                                     # ID en Cloud post-sync
      t.string  :node_token,            null: false                      # Token de vinculación
      t.string  :timezone,              default: "America/Bogota"
      t.string  :address
      t.datetime :last_sync_at
      t.datetime :created_at,           null: false
      t.datetime :updated_at,           null: false
    end

    execute "ALTER TABLE restaurants ADD CONSTRAINT pk_restaurants PRIMARY KEY (id);" rescue nil
  end

  def down
    drop_table :restaurants
  end
end

# ── 002 — Mesas ──────────────────────────────────────────────────
# edge/db/migrate/20260401000002_create_tables.rb

class CreateTables < ActiveRecord::Migration[8.0]
  def change
    create_table :tables, id: false do |t|
      t.string  :id,              null: false   # ULID
      t.string  :restaurant_id,   null: false
      t.string  :number,          null: false   # "1", "2", "Terraza-1"
      t.string  :label                          # Nombre descriptivo opcional
      t.string  :status,          default: "available"
                                                # available | occupied | reserved
      t.integer :capacity
      t.datetime :created_at,     null: false
      t.datetime :updated_at,     null: false
    end

    add_index :tables, :restaurant_id
    add_index :tables, [:restaurant_id, :number], unique: true

    execute <<~SQL
      CREATE TRIGGER fk_tables_restaurant
        BEFORE INSERT ON tables
        BEGIN
          SELECT RAISE(ABORT, 'restaurant not found')
          WHERE NOT EXISTS (SELECT 1 FROM restaurants WHERE id = NEW.restaurant_id);
        END;
    SQL
  end
end

# ── 003 — Categorías de menú ─────────────────────────────────────
# edge/db/migrate/20260401000003_create_categories.rb

class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, id: false do |t|
      t.string  :id,              null: false   # ULID
      t.string  :restaurant_id,   null: false
      t.string  :name,            null: false
      t.integer :position,        default: 0
      t.boolean :active,          default: true
      t.datetime :synced_at                     # Última sync desde Cloud
      t.datetime :created_at,     null: false
      t.datetime :updated_at,     null: false
    end

    add_index :categories, :restaurant_id
    add_index :categories, [:restaurant_id, :position]
  end
end

# ── 004 — Productos ──────────────────────────────────────────────
# edge/db/migrate/20260401000004_create_products.rb

class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products, id: false do |t|
      t.string  :id,              null: false   # ULID
      t.string  :restaurant_id,   null: false
      t.string  :category_id,     null: false
      t.string  :name,            null: false
      t.text    :description
      t.decimal :price,           null: false, precision: 10, scale: 2
      t.boolean :available,       default: true
      t.integer :position,        default: 0
      t.string  :image_url
      t.datetime :synced_at                     # Última sync desde Cloud
      t.datetime :created_at,     null: false
      t.datetime :updated_at,     null: false
    end

    add_index :products, :restaurant_id
    add_index :products, :category_id
    add_index :products, [:restaurant_id, :available]
  end
end

# ── 005 — Pedidos ────────────────────────────────────────────────
# edge/db/migrate/20260401000005_create_orders.rb

class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders, id: false do |t|
      t.string  :id,              null: false   # ULID — ID global único
      t.string  :restaurant_id,   null: false
      t.string  :table_id,        null: false
      t.string  :status,          default: "open"
                                                # open | in_progress | ready | closed | cancelled
      t.string  :waiter_name
      t.decimal :subtotal,        precision: 10, scale: 2, default: 0
      t.decimal :tax,             precision: 10, scale: 2, default: 0
      t.decimal :total,           precision: 10, scale: 2, default: 0
      t.text    :notes
      t.datetime :opened_at,      null: false
      t.datetime :closed_at
      t.datetime :synced_at                     # Null = pendiente de sync
      t.string  :sync_status,     default: "pending"
                                                # pending | synced | conflict
      t.datetime :created_at,     null: false
      t.datetime :updated_at,     null: false
    end

    add_index :orders, :restaurant_id
    add_index :orders, :table_id
    add_index :orders, :status
    add_index :orders, :synced_at             # Para el Sync Agent
    add_index :orders, [:restaurant_id, :sync_status]
  end
end

# ── 006 — Items de pedido ────────────────────────────────────────
# edge/db/migrate/20260401000006_create_order_items.rb

class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items, id: false do |t|
      t.string  :id,              null: false   # ULID
      t.string  :order_id,        null: false
      t.string  :product_id,      null: false
      t.string  :product_name,    null: false   # Snapshot del nombre al momento del pedido
      t.decimal :unit_price,      null: false, precision: 10, scale: 2
                                                # Snapshot del precio al momento del pedido
      t.integer :quantity,        null: false, default: 1
      t.decimal :subtotal,        precision: 10, scale: 2
      t.text    :notes
      t.string  :status,          default: "pending"
                                                # pending | preparing | ready | served
      t.datetime :synced_at
      t.datetime :created_at,     null: false
      t.datetime :updated_at,     null: false
    end

    add_index :order_items, :order_id
    add_index :order_items, :product_id
    add_index :order_items, [:order_id, :status]
  end
end

# ── 007 — Operation Log (Outbox Pattern) ─────────────────────────
# edge/db/migrate/20260401000007_create_sync_operations.rb
#
# CRÍTICO: Esta tabla es el corazón del sistema offline.
# Toda mutación de datos debe insertar una SyncOperation
# en la MISMA transacción de base de datos.
# El Sync Agent procesa esta cola en background.

class CreateSyncOperations < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_operations, id: false do |t|
      t.string   :id,             null: false   # ULID — ordering cronológico garantizado
      t.string   :restaurant_id,  null: false
      t.string   :operation_type, null: false
                                                # create | update | delete
      t.string   :entity_type,    null: false
                                                # Order | OrderItem | Table | Product
      t.string   :entity_id,      null: false   # ULID de la entidad afectada
      t.text     :payload,        null: false   # JSON completo de la entidad
      t.string   :status,         default: "pending"
                                                # pending | processing | synced | failed
      t.integer  :retry_count,    default: 0
      t.text     :last_error                    # Último error para diagnóstico
      t.datetime :created_at,     null: false   # Timestamp local del evento
      t.datetime :synced_at                     # Null = no sincronizado aún
    end

    # Índices críticos para el Sync Agent
    add_index :sync_operations, [:restaurant_id, :status]
    add_index :sync_operations, :status
    add_index :sync_operations, :created_at     # ULID ya da orden, pero esto acelera queries
    add_index :sync_operations, :entity_id

    # Trigger: append-only — nunca modificar operations existentes
    execute <<~SQL
      CREATE TRIGGER prevent_sync_operation_update
        BEFORE UPDATE OF operation_type, entity_type, entity_id, payload ON sync_operations
        BEGIN
          SELECT RAISE(ABORT, 'sync_operations payload is immutable');
        END;
    SQL
  end
end
