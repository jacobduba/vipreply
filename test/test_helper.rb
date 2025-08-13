# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def login_as_account1(include_gmail_scopes: true)
      OmniAuth.config.test_mode = true

      scopes = ["openid", "https://www.googleapis.com/auth/userinfo.profile", "https://www.googleapis.com/auth/userinfo.email"]

      if include_gmail_scopes
        scopes += ["https://www.googleapis.com/auth/gmail.send", "https://www.googleapis.com/auth/gmail.readonly"]
      end

      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "123456789",
        credentials: {
          token: "123456789",
          refresh_token: "123456789",
          expires_at: Time.current + 1.hour,
          expires: true,
          scope: scopes.join(" ")
        },
        email: "account1@example.com",
        first_name: "User",
        last_name: "Example",
        image_url: "https://example.com/image.jpg",
        info: {
          email: "user@example.com",
          name: "User Example"
        }
      )

      get auth_callback_path(provider: "google_oauth2")
    end
  end
end
