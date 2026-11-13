class SubmissionBodyGuard
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"].match?(%r{\A/volunteer_submissions(?:/|\.|\z)})
      env["action_dispatch.request.request_parameters"] = {}
    end
    @app.call(env)
  end
end
