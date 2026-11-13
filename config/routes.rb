Rails.application.routes.draw do
  post "/volunteer_submissions", to: "volunteer_submissions#create"
end
