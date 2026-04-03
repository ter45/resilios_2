# ══════════════════════════════════════════════════════════════════
#  Poblar archivos de migración con el contenido correcto
#  Ejecutar desde: E:\resilios\edge\
#  Uso: .\populate_migrations.ps1
# ══════════════════════════════════════════════════════════════════

$migrateDir = "db\migrate"

# Obtener archivos generados por Rails (con timestamp)
$files = Get-ChildItem "$migrateDir\*.rb" | Where-Object { $_.Name -ne "migrations_edge.rb" } | Sort-Object Name

Write-Host "Archivos encontrados:" -ForegroundColor Cyan
$files | ForEach-Object { Write-Host "  $_" }

# Contenido de cada migración
$migrations = @{
  "enable_wal_and_create_restaurants" = @'
class EnableWalAndCreateRestaurants < ActiveRecord::Migration[8.0]
  def up
    execute "PRAGMA journal_mode=WAL;"
    execute "PRAGMA synchronous=NORMAL;"
    execute "PRAGMA cache_size=-64000;"
    execute "PRAGMA foreign_keys=ON;"

    create_table :restaurants, id: false do |t|
      t.string   :id,                   null: false
      t.string   :name,                 null: false
      t.string   :cloud_restaurant_id
      t.string   :node_token,           null: false
      t.string   :timezone,             default: "America/Bogota"
      t.string   :address
      t.datetime :last_sync_at
      t.datetime :created_at,           null: false
      t.datetime :updated_at,           null: false
    end

    execute "CREATE UNIQUE INDEX idx_restaurants_id ON restaurants(id);"
  end

  def down
    drop_table :restaurants
  end
end
'@

  "create_tables" = @'
class CreateTables < ActiveRecord::Migration[8.0]
  def change
    create_table :tables, id: false do |t|
      t.string   :id,            null: false
      t.string   :restaurant_id, null: false
      t.string   :number,        null: false
      t.string   :label
      t.string   :status,        default: "available"
      t.integer  :capacity
      t.datetime :created_at,    null: false
      t.datetime :updated_at,    null: false
    end

    add_index :tables, :restaurant_id
    add_index :tables, [:restaurant_id, :number], unique: true
    execute "CREATE UNIQUE INDEX idx_tables_id ON tables(id);"
  end
end
'@

  "create_categories" = @'
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, id: false do |t|
      t.string   :id,            null: false
      t.string   :restaurant_id, null: false
      t.string   :name,          null: false
      t.integer  :position,      default: 0
      t.boolean  :active,        default: true
      t.datetime :synced_at
      t.datetime :created_at,    null: false
      t.datetime :updated_at,    null: false
    end

    add_index :categories, :restaurant_id
    execute "CREATE UNIQUE INDEX idx_categories_id ON categories(id);"
  end
end
'@

  "create_products" = @'
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products, id: false do |t|
      t.string   :id,            null: false
      t.string   :restaurant_id, null: false
      t.string   :category_id,   null: false
      t.string   :name,          null: false
      t.text     :description
      t.decimal  :price,         null: false, precision: 10, scale: 2
      t.boolean  :available,     default: true
      t.integer  :position,      default: 0
      t.string   :image_url
      t.datetime :synced_at
      t.datetime :created_at,    null: false
      t.datetime :updated_at,    null: false
    end

    add_index :products, :restaurant_id
    add_index :products, :category_id
    execute "CREATE UNIQUE INDEX idx_products_id ON products(id);"
  end
end
'@

  "create_orders" = @'
class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders, id: false do |t|
      t.string   :id,            null: false
      t.string   :restaurant_id, null: false
      t.string   :table_id,      null: false
      t.string   :status,        default: "open"
      t.string   :waiter_name
      t.decimal  :subtotal,      precision: 10, scale: 2, default: 0
      t.decimal  :tax,           precision: 10, scale: 2, default: 0
      t.decimal  :total,         precision: 10, scale: 2, default: 0
      t.text     :notes
      t.datetime :opened_at,     null: false
      t.datetime :closed_at
      t.datetime :synced_at
      t.string   :sync_status,   default: "pending"
      t.datetime :created_at,    null: false
      t.datetime :updated_at,    null: false
    end

    add_index :orders, :restaurant_id
    add_index :orders, :table_id
    add_index :orders, :status
    add_index :orders, :synced_at
    execute "CREATE UNIQUE INDEX idx_orders_id ON orders(id);"
  end
end
'@

  "create_order_items" = @'
class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items, id: false do |t|
      t.string   :id,           null: false
      t.string   :order_id,     null: false
      t.string   :product_id,   null: false
      t.string   :product_name, null: false
      t.decimal  :unit_price,   null: false, precision: 10, scale: 2
      t.integer  :quantity,     null: false, default: 1
      t.decimal  :subtotal,     precision: 10, scale: 2
      t.text     :notes
      t.string   :status,       default: "pending"
      t.datetime :synced_at
      t.datetime :created_at,   null: false
      t.datetime :updated_at,   null: false
    end

    add_index :order_items, :order_id
    add_index :order_items, :product_id
    execute "CREATE UNIQUE INDEX idx_order_items_id ON order_items(id);"
  end
end
'@

  "create_sync_operations" = @'
class CreateSyncOperations < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_operations, id: false do |t|
      t.string   :id,             null: false
      t.string   :restaurant_id,  null: false
      t.string   :operation_type, null: false
      t.string   :entity_type,    null: false
      t.string   :entity_id,      null: false
      t.text     :payload,        null: false
      t.string   :status,         default: "pending"
      t.integer  :retry_count,    default: 0
      t.text     :last_error
      t.datetime :created_at,     null: false
      t.datetime :synced_at
    end

    add_index :sync_operations, [:restaurant_id, :status]
    add_index :sync_operations, :status
    add_index :sync_operations, :created_at
    add_index :sync_operations, :entity_id
    execute "CREATE UNIQUE INDEX idx_sync_operations_id ON sync_operations(id);"

    execute <<~SQL
      CREATE TRIGGER prevent_sync_operation_update
        BEFORE UPDATE OF operation_type, entity_type, entity_id, payload ON sync_operations
        BEGIN
          SELECT RAISE(ABORT, 'sync_operations payload is immutable');
        END;
    SQL
  end
end
'@
}

# Mapear cada archivo generado a su contenido
$nameMap = @{
  "enable_wal_and_create_restaurants" = "enable_wal_and_create_restaurants"
  "create_tables"                     = "create_tables"
  "create_categories"                 = "create_categories"
  "create_products"                   = "create_products"
  "create_orders"                     = "create_orders"
  "create_order_items"                = "create_order_items"
  "create_sync_operations"            = "create_sync_operations"
}

$files | ForEach-Object {
  $file = $_
  $matched = $false

  foreach ($key in $nameMap.Keys) {
    if ($file.Name -match $key) {
      $content = $migrations[$key]
      Set-Content -Path $file.FullName -Value $content -Encoding UTF8
      Write-Host "[OK] $($file.Name)" -ForegroundColor Green
      $matched = $true
      break
    }
  }

  if (-not $matched) {
    Write-Host "[SKIP] $($file.Name) — no match encontrado" -ForegroundColor Yellow
  }
}

Write-Host "`nMigraciones listas. Ejecuta:" -ForegroundColor Cyan
Write-Host "  bundle exec rails db:migrate" -ForegroundColor White
