# frozen_string_literal: true

# Skip during asset precompilation (credentials aren't available during Docker build)
return if ENV["SECRET_KEY_BASE_DUMMY"].present?

POSTHOG = PostHog::Client.new(
  api_key: Rails.application.credentials.posthog_api_key,
  host: "https://e.vipreply.ai",
  on_error: proc { |status, msg| Rails.logger.error("PostHog error: #{status} - #{msg}") }
)
