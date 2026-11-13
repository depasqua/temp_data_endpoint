require "digest"
require "json"
require "openssl"
require "webrick"
require_relative "lib/volunteer_submission"

class SubmissionEndpoint < WEBrick::HTTPServlet::AbstractServlet
  MAX_BODY_SIZE = 65_536

  def initialize(server, store, api_key)
    super(server)
    @store = store
    @key_digest = Digest::SHA256.digest(api_key)
  end

  def service(request, response)
    response["Content-Type"] = "application/json"
    response["Cache-Control"] = "no-store"
    if request.path != "/volunteer_submissions"
      return respond(response, 404, error: "Not found")
    end
    unless request.request_method == "POST"
      response["Allow"] = "POST"
      return respond(response, 405, error: "Method not allowed")
    end
    supplied_key = request["X-API-Key"].to_s
    unless !supplied_key.empty? && OpenSSL.fixed_length_secure_compare(@key_digest, Digest::SHA256.digest(supplied_key))
      return respond(response, 401, error: "Unauthorized")
    end
    unless request.content_type.to_s.split(";").first.strip.downcase == "application/json"
      return respond(response, 415, error: "Content-Type must be application/json")
    end
    if request["transfer-encoding"] || !request["content-length"]
      return respond(response, 411, error: "Content-Length required")
    end
    if request.content_length > MAX_BODY_SIZE
      return respond(response, 413, error: "Request body too large")
    end

    begin
      data = JSON.parse(request.body.to_s)
    rescue JSON::ParserError
      return respond(response, 400, error: "Invalid JSON")
    end
    unless data.is_a?(Hash) && !data.empty?
      return respond(response, 400, error: "A non-empty JSON object is required")
    end

    respond(response, 201, id: @store.create(data))
  end

  private

  def respond(response, status, body)
    response.status = status
    response.body = JSON.generate(body)
  end
end

def build_server(api_key:, data_path:, host: "127.0.0.1", port: 9292, logger: WEBrick::Log.new($stderr))
  raise ArgumentError, "API_KEY must be set" if api_key.to_s.strip.empty?

  server = WEBrick::HTTPServer.new(BindAddress: host, Port: port, Logger: logger, AccessLog: [])
  server.mount("/volunteer_submissions", SubmissionEndpoint, VolunteerSubmission.new(data_path), api_key)
  server
end

if $PROGRAM_NAME == __FILE__
  server = build_server(
    api_key: ENV["API_KEY"],
    data_path: ENV.fetch("DATA_PATH", File.join(__dir__, "data", "submissions.pstore")),
    host: ENV.fetch("HOST", "127.0.0.1"),
    port: Integer(ENV.fetch("PORT", "9292"))
  )
  %w[INT TERM].each { |signal| trap(signal) { server.shutdown } }
  server.start
end
