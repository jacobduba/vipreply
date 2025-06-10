# frozen_string_literal: true

module ApplicationHelper
  def google_oauth_url(prompt_consent: false)
    if prompt_consent
      "/auth/google_oauth2?prompt=consent"
    else
      "/auth/google_oauth2"
    end
  end
end
