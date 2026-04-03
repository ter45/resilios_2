$migrateDir = "db\migrate"
$files = Get-ChildItem "$migrateDir\*.rb" | Where-Object { $_.Name -ne "migrations_edge.rb" } | Sort-Object Name

Write-Host "Poblando migraciones..." -ForegroundColor Cyan

foreach ($file in $files) {
    $name = $file.Name
    $path = $file.FullName

    if ($name -match "enable_wal") {
        $c = "class EnableWalAndCreateRestaurants < ActiveRecord::Migration[8.0]`n  def up`n    execute `"PRAGMA journal_mode=WAL;`"`n    execute `"PRAGMA synchronous=NORMAL;`"`n    execute `"PRAGMA foreign_keys=ON;`"`n    create_table :restaurants, id: false do |t|`n      t.string   :id,                   null: false`n      t.string   :name,                 null: false`n      t.string   :cloud_restaurant_id`n      t.string   :node_token,           null: false`n      t.string   :timezone,             default: `"America/Bogota`"`n      t.string   :address`n      t.datetime :last_sync_at`n      t.datetime :created_at,           null: false`n      t.datetime :updated_at,           null: false`n    end`n    execute `"CREATE UNIQUE INDEX idx_restaurants_id ON restaurants(id);`"`n  end`n  def down`n    drop_table :restaurants`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_tables") {
        $c = "class CreateTables < ActiveRecord::Migration[8.0]`n  def change`n    create_table :tables, id: false do |t|`n      t.string   :id,            null: false`n      t.string   :restaurant_id, null: false`n      t.string   :number,        null: false`n      t.string   :label`n      t.string   :status,        default: `"available`"`n      t.integer  :capacity`n      t.datetime :created_at,    null: false`n      t.datetime :updated_at,   null: false`n    end`n    add_index :tables, :restaurant_id`n    add_index :tables, [:restaurant_id, :number], unique: true`n    execute `"CREATE UNIQUE INDEX idx_tables_id ON tables(id);`"`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_categories") {
        $c = "class CreateCategories < ActiveRecord::Migration[8.0]`n  def change`n    create_table :categories, id: false do |t|`n      t.string   :id,            null: false`n      t.string   :restaurant_id, null: false`n      t.string   :name,          null: false`n      t.integer  :position,      default: 0`n      t.boolean  :active,        default: true`n      t.datetime :synced_at`n      t.datetime :created_at,    null: false`n      t.datetime :updated_at,   null: false`n    end`n    add_index :categories, :restaurant_id`n    execute `"CREATE UNIQUE INDEX idx_categories_id ON categories(id);`"`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_products") {
        $c = "class CreateProducts < ActiveRecord::Migration[8.0]`n  def change`n    create_table :products, id: false do |t|`n      t.string   :id,            null: false`n      t.string   :restaurant_id, null: false`n      t.string   :category_id,   null: false`n      t.string   :name,          null: false`n      t.text     :description`n      t.decimal  :price,         null: false, precision: 10, scale: 2`n      t.boolean  :available,     default: true`n      t.integer  :position,      default: 0`n      t.string   :image_url`n      t.datetime :synced_at`n      t.datetime :created_at,    null: false`n      t.datetime :updated_at,   null: false`n    end`n    add_index :products, :restaurant_id`n    add_index :products, :category_id`n    execute `"CREATE UNIQUE INDEX idx_products_id ON products(id);`"`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_orders" -and $name -notmatch "items") {
        $c = "class CreateOrders < ActiveRecord::Migration[8.0]`n  def change`n    create_table :orders, id: false do |t|`n      t.string   :id,            null: false`n      t.string   :restaurant_id, null: false`n      t.string   :table_id,      null: false`n      t.string   :status,        default: `"open`"`n      t.string   :waiter_name`n      t.decimal  :subtotal,      precision: 10, scale: 2, default: 0`n      t.decimal  :tax,           precision: 10, scale: 2, default: 0`n      t.decimal  :total,         precision: 10, scale: 2, default: 0`n      t.text     :notes`n      t.datetime :opened_at,     null: false`n      t.datetime :closed_at`n      t.datetime :synced_at`n      t.string   :sync_status,   default: `"pending`"`n      t.datetime :created_at,    null: false`n      t.datetime :updated_at,   null: false`n    end`n    add_index :orders, :restaurant_id`n    add_index :orders, :table_id`n    add_index :orders, :status`n    execute `"CREATE UNIQUE INDEX idx_orders_id ON orders(id);`"`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_order_items") {
        $c = "class CreateOrderItems < ActiveRecord::Migration[8.0]`n  def change`n    create_table :order_items, id: false do |t|`n      t.string   :id,           null: false`n      t.string   :order_id,     null: false`n      t.string   :product_id,   null: false`n      t.string   :product_name, null: false`n      t.decimal  :unit_price,   null: false, precision: 10, scale: 2`n      t.integer  :quantity,     null: false, default: 1`n      t.decimal  :subtotal,     precision: 10, scale: 2`n      t.text     :notes`n      t.string   :status,       default: `"pending`"`n      t.datetime :synced_at`n      t.datetime :created_at,   null: false`n      t.datetime :updated_at,  null: false`n    end`n    add_index :order_items, :order_id`n    add_index :order_items, :product_id`n    execute `"CREATE UNIQUE INDEX idx_order_items_id ON order_items(id);`"`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_sync_operations") {
        $c = "class CreateSyncOperations < ActiveRecord::Migration[8.0]`n  def change`n    create_table :sync_operations, id: false do |t|`n      t.string   :id,             null: false`n      t.string   :restaurant_id,  null: false`n      t.string   :operation_type, null: false`n      t.string   :entity_type,    null: false`n      t.string   :entity_id,      null: false`n      t.text     :payload,        null: false`n      t.string   :status,         default: `"pending`"`n      t.integer  :retry_count,    default: 0`n      t.text     :last_error`n      t.datetime :created_at,     null: false`n      t.datetime :synced_at`n    end`n    add_index :sync_operations, [:restaurant_id, :status]`n    add_index :sync_operations, :status`n    add_index :sync_operations, :created_at`n    add_index :sync_operations, :entity_id`n    execute `"CREATE UNIQUE INDEX idx_sync_operations_id ON sync_operations(id);`"`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
}

Write-Host "`nListo. Ahora ejecuta: bundle exec rails db:migrate" -ForegroundColor Cyan
