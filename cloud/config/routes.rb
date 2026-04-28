Rails.application.routes.draw do
  get "/health", to: "health#show"

  namespace :api do
    namespace :v1 do
      scope :sync do
        post "/operations", to: "sync#operations"
        get  "/status",     to: "sync#status"
        post "/heartbeat",  to: "sync#heartbeat"
        post "/link",       to: "sync#link"
      end
    end
  end
end
