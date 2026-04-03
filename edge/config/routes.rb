Rails.application.routes.draw do
  get "/health", to: "api/v1/status#health"

  namespace :api do
    namespace :v1 do
      get  "/status", to: "status#show"

      resources :orders, only: %i[index show create update destroy] do
        member do
          post :close
        end
        resources :items, controller: "order_items", only: %i[create update destroy] do
          member do
            patch :status, action: :update_status
          end
        end
      end

      resources :tables, only: %i[index show update]

      scope :menu do
        get "/",         to: "menu#index",    as: :menu
        get "/products", to: "menu#products", as: :menu_products
      end

      scope :kds do
        get  "/queue",            to: "kds#queue"
        get  "/orders",           to: "kds#orders"
        post "/items/:id/ready",  to: "kds#item_ready",  as: :kds_item_ready
        post "/orders/:id/ready", to: "kds#order_ready", as: :kds_order_ready
      end
    end
  end
end
