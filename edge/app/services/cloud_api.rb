# ══════════════════════════════════════════════════════════════════
#  edge/app/services/cloud_api.rb
#
#  Cliente HTTP para comunicación Edge → Cloud.
#  Maneja autenticación, timeouts y errores de red.
# ══════════════════════════════════════════════════════════════════

require "net/http"
require "json"

class CloudApi
  class NetworkError < StandardError; end
  class AuthError    < StandardError; end
  class ServerError  < StandardError; end

  DEFAULT_TIMEOUT = 15  # segundos

  def initialize(base_url:, node_token:)
    @base_url   = base_url.chomp("/")
    @node_token = node_token
    @node_id    = ENV.fetch("RESILIOS_NODE_ID", "unknown")
  end

  # ── Métodos HTTP ──────────────────────────────────────────────

  def post(path, body)
    request(:post, path, body)
  end

  def get(path, params = {})
    request(:get, path, params)
  end

  def health_check(timeout: 3)
    uri = URI("#{@base_url}/health")
    response = Net::HTTP.start(uri.host, uri.port,
      use_ssl:        uri.scheme == "https",
      open_timeout:   timeout,
      read_timeout:   timeout
    ) { |http| http.get(uri.path) }

    response.code.to_i == 200
  rescue
    false
  end

  private

  def request(method, path, body = {})
    uri      = URI("#{@base_url}/api/v1#{path}")
    http     = build_http(uri)
    req      = build_request(method, uri, body)
    response = http.request(req)

    handle_response(response)

  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
    raise NetworkError, "#{e.class}: #{e.message}"
  end

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == "https"
    http.open_timeout = DEFAULT_TIMEOUT
    http.read_timeout = DEFAULT_TIMEOUT
    http
  end

  def build_request(method, uri, body)
    req_class = method == :post ? Net::HTTP::Post : Net::HTTP::Get
    req = req_class.new(uri)

    req["Content-Type"]  = "application/json"
    req["Authorization"] = "Bearer #{@node_token}"
    req["X-Node-ID"]     = @node_id
    req["X-Node-Version"] = Edge::VERSION rescue "unknown"

    req.body = body.to_json if method == :post
    req
  end

  def handle_response(response)
    case response.code.to_i
    when 200, 201
      JSON.parse(response.body)
    when 401, 403
      raise AuthError, "HTTP #{response.code}: #{response.body}"
    when 422
      raise ServerError, "Unprocessable: #{response.body}"
    when 429
      raise NetworkError, "Rate limit exceeded"
    when 500..599
      raise ServerError, "Server error #{response.code}"
    else
      raise NetworkError, "Unexpected response: #{response.code}"
    end
  end
end
