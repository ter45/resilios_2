$migrateDir = "db\migrate"
$files = Get-ChildItem "$migrateDir\*.rb" | Sort-Object Name

Write-Host "Poblando migraciones Cloud..." -ForegroundColor Cyan

foreach ($file in $files) {
    $name = $file.Name
    $path = $file.FullName

    if ($name -match "enable_extensions") {
        $c = "class EnableExtensions < ActiveRecord::Migration[8.0]`n  def change`n    enable_extension 'pgcrypto'`n    enable_extension 'pg_trgm'`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_accounts") {
        $c = "class CreateAccounts < ActiveRecord::Migration[8.0]`n  def change`n    create_table :accounts, id: false do |t|`n      t.string   :id,                 null: false`n      t.string   :name,               null: false`n      t.string   :email,              null: false`n      t.string   :password_digest,    null: false`n      t.string   :stripe_customer_id`n      t.string   :plan,               default: 'trial'`n      t.string   :status,             default: 'active'`n      t.string   :timezone,           default: 'America/Bogota'`n      t.jsonb    :metadata,           default: {}`n      t.datetime :trial_ends_at`n      t.timestamps`n    end`n    add_index :accounts, :id,    unique: true`n    add_index :accounts, :email, unique: true`n    add_index :accounts, :status`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_subscriptions") {
        $c = "class CreateSubscriptions < ActiveRecord::Migration[8.0]`n  def change`n    create_table :subscriptions, id: false do |t|`n      t.string   :id,                     null: false`n      t.string   :account_id,             null: false`n      t.string   :stripe_subscription_id, null: false`n      t.string   :plan,                   null: false`n      t.string   :status,                 null: false`n      t.integer  :orders_per_month_limit, default: 500`n      t.datetime :current_period_start`n      t.datetime :current_period_end`n      t.datetime :cancelled_at`n      t.timestamps`n    end`n    add_index :subscriptions, :id,                     unique: true`n    add_index :subscriptions, :account_id`n    add_index :subscriptions, :stripe_subscription_id, unique: true`n    add_index :subscriptions, :status`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_restaurants") {
        $c = "class CreateRestaurants < ActiveRecord::Migration[8.0]`n  def change`n    create_table :restaurants, id: false do |t|`n      t.string   :id,         null: false`n      t.string   :account_id, null: false`n      t.string   :name,       null: false`n      t.string   :timezone,   default: 'America/Bogota'`n      t.string   :address`n      t.string   :phone`n      t.string   :currency,   default: 'COP'`n      t.jsonb    :settings,   default: {}`n      t.boolean  :active,     default: true`n      t.timestamps`n    end`n    add_index :restaurants, :id,         unique: true`n    add_index :restaurants, :account_id`n    add_index :restaurants, [:account_id, :active]`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_edge_nodes") {
        $c = "class CreateEdgeNodes < ActiveRecord::Migration[8.0]`n  def change`n    create_table :edge_nodes, id: false do |t|`n      t.string   :id,                 null: false`n      t.string   :account_id,         null: false`n      t.string   :restaurant_id,      null: false`n      t.string   :node_token_hash,    null: false`n      t.string   :version`n      t.string   :ip_address`n      t.string   :hostname`n      t.jsonb    :telemetry,           default: {}`n      t.string   :sync_status,        default: 'unknown'`n      t.integer  :pending_operations, default: 0`n      t.datetime :last_seen_at`n      t.datetime :last_sync_at`n      t.timestamps`n    end`n    add_index :edge_nodes, :id,              unique: true`n    add_index :edge_nodes, :restaurant_id`n    add_index :edge_nodes, :node_token_hash, unique: true`n    add_index :edge_nodes, :last_seen_at`n    add_index :edge_nodes, :sync_status`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_orders" -and $name -notmatch "items") {
        $c = "class CreateOrders < ActiveRecord::Migration[8.0]`n  def change`n    create_table :orders, id: false do |t|`n      t.string   :id,            null: false`n      t.string   :restaurant_id, null: false`n      t.string   :edge_node_id`n      t.string   :table_label,   null: false`n      t.string   :status,        null: false, default: 'open'`n      t.string   :waiter_name`n      t.decimal  :subtotal,      precision: 10, scale: 2, default: 0`n      t.decimal  :tax,           precision: 10, scale: 2, default: 0`n      t.decimal  :total,         precision: 10, scale: 2, default: 0`n      t.text     :notes`n      t.string   :origin,        default: 'edge'`n      t.boolean  :was_offline,   default: false`n      t.datetime :opened_at,     null: false`n      t.datetime :closed_at`n      t.datetime :synced_at,     null: false`n      t.timestamps`n    end`n    add_index :orders, :id,            unique: true`n    add_index :orders, :restaurant_id`n    add_index :orders, :edge_node_id`n    add_index :orders, :status`n    add_index :orders, :opened_at`n    add_index :orders, [:restaurant_id, :opened_at]`n    add_index :orders, [:restaurant_id, :was_offline]`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_order_items") {
        $c = "class CreateOrderItems < ActiveRecord::Migration[8.0]`n  def change`n    create_table :order_items, id: false do |t|`n      t.string   :id,           null: false`n      t.string   :order_id,     null: false`n      t.string   :product_name, null: false`n      t.decimal  :unit_price,   null: false, precision: 10, scale: 2`n      t.integer  :quantity,     null: false, default: 1`n      t.decimal  :subtotal,     precision: 10, scale: 2`n      t.text     :notes`n      t.string   :status,       default: 'served'`n      t.datetime :synced_at,    null: false`n      t.timestamps`n    end`n    add_index :order_items, :id,       unique: true`n    add_index :order_items, :order_id`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
    elseif ($name -match "create_sync_logs") {
        $c = "class CreateSyncLogs < ActiveRecord::Migration[8.0]`n  def change`n    create_table :sync_logs, id: false do |t|`n      t.string   :id,             null: false`n      t.string   :edge_node_id,   null: false`n      t.string   :restaurant_id,  null: false`n      t.string   :operation_id,   null: false`n      t.string   :operation_type, null: false`n      t.string   :entity_type,    null: false`n      t.string   :entity_id,      null: false`n      t.jsonb    :payload,        null: false`n      t.string   :result,         null: false`n      t.jsonb    :conflict_detail`n      t.integer  :processing_ms`n      t.datetime :received_at,    null: false`n      t.datetime :processed_at,   null: false`n    end`n    add_index :sync_logs, :id,           unique: true`n    add_index :sync_logs, :edge_node_id`n    add_index :sync_logs, :operation_id, unique: true`n    add_index :sync_logs, [:edge_node_id, :received_at]`n    add_index :sync_logs, :result`n    add_index :sync_logs, :entity_id`n  end`nend"
        Set-Content -Path $path -Value $c -Encoding UTF8
        Write-Host "[OK] $name" -ForegroundColor Green
    }
}

Write-Host "`nListo. Ejecuta: bundle exec rails db:migrate" -ForegroundColor Cyan
