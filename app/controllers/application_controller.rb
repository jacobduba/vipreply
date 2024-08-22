class ApplicationController < ActionController::Base
  http_basic_authenticate_with name: "demo", password: "emails"
end
