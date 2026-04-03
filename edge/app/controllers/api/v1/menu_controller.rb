module Api
  module V1
    class MenuController < BaseController
      def index
        categories = @restaurant.categories.active.includes(:products)
        render_ok(categories.map { |cat|
          { id: cat.id, name: cat.name, position: cat.position,
            products: cat.active_products.map { |p| serialize_product(p) } }
        })
      end

      def products
        render_ok(@restaurant.products.available.map { |p| serialize_product(p) })
      end

      private

      def serialize_product(p)
        { id: p.id, name: p.name, description: p.description,
          price: p.price.to_s, category_id: p.category_id,
          available: p.available, image_url: p.image_url }
      end
    end
  end
end
