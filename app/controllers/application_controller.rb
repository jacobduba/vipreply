class ApplicationController < ActionController::Base
  # http_basic_authenticate_with name: "demo", password: "emails"
  # before_action :authenticate

  def authenticate
    # authenticate_or_request_with_http_basic do |username, password|
    #   username == "admin" && password == "password"
    # end
  end
end
