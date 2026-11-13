require "minitest/autorun"
require "net/http"
require "pstore"
require "tmpdir"
require_relative "../app"

class AppTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @path = File.join(@directory, "data", "submissions.pstore")
    @server = build_server(api_key: "test-key", data_path: @path, port: 0,
                           logger: WEBrick::Log.new(File::NULL))
    started = Queue.new
    @server.config[:StartCallback] = proc { started << true }
    @thread = Thread.new { @server.start }
    started.pop
    @port = @server.listeners.first.addr[1]
  end

  def teardown
    @server.shutdown
    @thread.join
    FileUtils.remove_entry(@directory)
  end

  def post(body, key: "test-key", content_type: "application/json")
    request = Net::HTTP::Post.new("/volunteer_submissions")
    request["X-API-Key"] = key if key
    request["Content-Type"] = content_type
    request.body = body
    Net::HTTP.start("127.0.0.1", @port, nil) { |http| http.request(request) }
  end

  def test_accepts_and_persists_arbitrary_form_fields
    data = { "name" => "Volunteer", "email" => "volunteer@example.org",
             "interests" => ["advocacy"], "additional_fields" => { "available" => true } }
    response = post(JSON.generate(data))
    assert_equal "201", response.code
    id = JSON.parse(response.body).fetch("id")
    store = PStore.new(@path)
    store.transaction(true) do
      assert_equal data, store[id]["data"]
      refute_nil Time.iso8601(store[id]["created_at"])
    end
    assert_equal 0o600, File.stat(@path).mode & 0o777
  end

  def test_rejects_missing_and_incorrect_keys_without_saving
    [nil, "", "wrong"].each do |key|
      assert_equal "401", post('{"name":"Volunteer"}', key: key).code
    end
    store = PStore.new(@path)
    store.transaction(true) { assert_empty store.roots }
  end

  def test_rejects_invalid_input
    assert_equal "400", post("{").code
    assert_equal "400", post("[]").code
    assert_equal "400", post("{}").code
    assert_equal "415", post("name=Volunteer", content_type: "application/x-www-form-urlencoded").code
    assert_equal "413", post(JSON.generate("field" => "a" * 65_536)).code
  end

  def test_only_accepts_post_on_the_exact_route
    response = Net::HTTP.start("127.0.0.1", @port, nil) do |http|
      http.request(Net::HTTP::Get.new("/volunteer_submissions"))
    end
    assert_equal "405", response.code
    assert_equal "POST", response["Allow"]
    response = Net::HTTP.start("127.0.0.1", @port, nil) do |http|
      http.request(Net::HTTP::Post.new("/volunteer_submissions/extra"))
    end
    assert_equal "404", response.code
  end

  def test_requires_configured_key
    assert_raises(ArgumentError) { build_server(api_key: "", data_path: @path) }
    assert_raises(ArgumentError) { build_server(api_key: "  ", data_path: @path) }
  end
end
