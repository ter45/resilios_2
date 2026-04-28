class HealthController < ActionController::API
  def show
    render json: { status: "ok", version: "1.0.0", service: "resilios-cloud", time: Time.current.iso8601 }, status: :ok
  end
end
