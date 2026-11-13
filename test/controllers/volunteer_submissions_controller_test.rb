require "test_helper"

class VolunteerSubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_key = ENV["API_KEY"]
    ENV["API_KEY"] = "test-key"
    @headers = { "X-API-Key" => "test-key", "Content-Type" => "application/json" }
  end

  teardown do
    ENV["API_KEY"] = @original_key
  end

  test "persists arbitrary form data and timestamps" do
    data = { "name" => "Volunteer", "email" => "volunteer@example.org",
             "interests" => [ "advocacy" ], "extra" => { "available" => true } }
    assert_difference "VolunteerSubmission.count", 1 do
      post "/volunteer_submissions", params: JSON.generate(data), headers: @headers
    end
    assert_response :created
    submission = VolunteerSubmission.find(response.parsed_body.fetch("id"))
    assert_equal data, submission.data
    assert submission.created_at
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "rejects absent wrong and unconfigured keys without saving" do
    [ nil, "", "wrong" ].each do |key|
      assert_no_difference "VolunteerSubmission.count" do
        post "/volunteer_submissions", params: '{"name":"Volunteer"}',
             headers: @headers.merge("X-API-Key" => key)
      end
      assert_response :unauthorized
    end
    [ nil, "", "  " ].each do |key|
      ENV["API_KEY"] = key
      post "/volunteer_submissions", params: '{"name":"Volunteer"}', headers: @headers
      assert_response :unauthorized
    end
  end

  test "rejects malformed empty and non-object input" do
    [ "{", "[]", "{}", "null", '"string"' ].each do |body|
      assert_no_difference "VolunteerSubmission.count" do
        post "/volunteer_submissions", params: body, headers: @headers
      end
      assert_response :bad_request
    end
  end

  test "requires JSON and limits body size" do
    post "/volunteer_submissions", params: "name=Volunteer",
         headers: @headers.merge("Content-Type" => "application/x-www-form-urlencoded")
    assert_response :unsupported_media_type
    assert_no_difference "VolunteerSubmission.count" do
      post "/volunteer_submissions", params: JSON.generate("field" => "a" * 65_536), headers: @headers
    end
    assert_response :content_too_large
  end

  test "only routes POST to the exact endpoint" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/volunteer_submissions", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/volunteer_submissions/extra", method: :post)
    end
  end

  test "authenticates before parsing JSON" do
    post "/volunteer_submissions", params: "{", headers: @headers.merge("X-API-Key" => "wrong")
    assert_response :unauthorized
  end
end
