# frozen_string_literal: true

POSTHOG = if Rails.application.credentials.posthog_api_key.present?
  PostHog::Client.new(
    api_key: Rails.application.credentials.posthog_api_key,
    host: "https://e.vipreply.ai",
    on_error: proc { |status, msg| Rails.logger.error("PostHog error: #{status} - #{msg}") }
  )
end
