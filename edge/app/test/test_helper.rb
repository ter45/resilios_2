# ══════════════════════════════════════════════════════════════════
#  edge/test/test_helper.rb
# ══════════════════════════════════════════════════════════════════

ENV["RAILS_ENV"] ||= "test"
ENV["EDGE_DEVICE_TOKEN"] = "test-device-token"
ENV["RESILIOS_NODE_ID"]  = "01TEST000000000000000000001"
ENV["RESILIOS_NODE_TOKEN"] = "test-node-token"
ENV["RESILIOS_CLOUD_URL"]  = "http://cloud.test"

require_relative "../config/environment"
require "rails/test_help"
require "minitest/autorun"

module ActiveSupport
  class TestCase
    # Helpers de fixtures compartidos
    include FactoryHelpers

    # Limpiar DB entre tests
    setup    { DatabaseCleaner.start }
    teardown { DatabaseCleaner.clean }

    parallelize(workers: :number_of_processors)
  end
end

# ── Helpers de fabricación de datos ──────────────────────────────
module FactoryHelpers
  def create_restaurant(attrs = {})
    Restaurant.create!({
      name:       "La Fogata Test",
      node_token: "test-node-token",
      timezone:   "America/Bogota"
    }.merge(attrs))
  end

  def create_table(restaurant, attrs = {})
    restaurant.tables.create!({
      number: attrs.delete(:number) || rand(1..99).to_s,
      status: "available"
    }.merge(attrs))
  end

  def create_category(restaurant, attrs = {})
    restaurant.categories.create!({
      name:     "Platos principales",
      position: 1,
      active:   true
    }.merge(attrs))
  end

  def create_product(restaurant, category, attrs = {})
    restaurant.products.create!({
      category:  category,
      name:      "Bandeja Paisa",
      price:     28_000,
      available: true
    }.merge(attrs))
  end

  def create_order(restaurant, table, attrs = {})
    restaurant.orders.create!({
      table:       table,
      waiter_name: "Carlos",
      status:      "open",
      opened_at:   Time.current
    }.merge(attrs))
  end

  def create_order_item(order, product, attrs = {})
    order.order_items.create!({
      product:  product,
      quantity: 1
    }.merge(attrs))
  end

  # Configuración completa de un restaurante para tests de integración
  def setup_full_restaurant
    restaurant = create_restaurant
    table1     = create_table(restaurant, number: "1")
    table2     = create_table(restaurant, number: "2")
    category   = create_category(restaurant)
    product1   = create_product(restaurant, category, name: "Bandeja Paisa",  price: 28_000)
    product2   = create_product(restaurant, category, name: "Ajiaco Bogotano", price: 22_000)

    { restaurant: restaurant, tables: [table1, table2],
      category: category, products: [product1, product2] }
  end
end

# ── Helper para requests a la API ─────────────────────────────────
module ApiRequestHelpers
  def auth_headers
    { "Authorization" => "Bearer test-device-token",
      "Content-Type"  => "application/json" }
  end

  def json_response
    JSON.parse(response.body)
  end

  def post_json(path, body)
    post path, params: body.to_json, headers: auth_headers
  end

  def patch_json(path, body)
    patch path, params: body.to_json, headers: auth_headers
  end
end
