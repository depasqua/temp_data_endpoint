require "digest"

class VolunteerSubmissionsController < ApplicationController
  MAX_BODY_SIZE = 65_536
  wrap_parameters false

  def create
    response.set_header("Cache-Control", "no-store")
    key = ENV["API_KEY"].to_s
    supplied_key = request.headers["X-API-Key"].to_s
    unless key.present? && supplied_key.present? &&
           ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.digest(key), Digest::SHA256.digest(supplied_key))
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    unless request.media_type == "application/json"
      return render json: { error: "Content-Type must be application/json" }, status: :unsupported_media_type
    end

    body = request.body.read(MAX_BODY_SIZE + 1)
    if body.bytesize > MAX_BODY_SIZE
      return render json: { error: "Request body too large" }, status: :content_too_large
    end

    begin
      data = JSON.parse(body)
    rescue JSON::ParserError
      return render json: { error: "Invalid JSON" }, status: :bad_request
    end
    submission = VolunteerSubmission.new(data: data)
    unless submission.valid?
      return render json: { error: "A non-empty JSON object is required" }, status: :bad_request
    end

    submission.save!
    render json: { id: submission.id }, status: :created
  end
end
