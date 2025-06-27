# frozen_string_literal: true

module ApplicationHelper
  def google_oauth_url(prompt_consent: false, request_gmail_scopes: false)
    gmail_scopes = "https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/gmail.send"
    
    if prompt_consent && request_gmail_scopes
      "/auth/google_oauth2?prompt=consent&scope=email,profile,#{gmail_scopes}"
    elsif prompt_consent
      "/auth/google_oauth2?prompt=consent"
    elsif request_gmail_scopes
      "/auth/google_oauth2?scope=email,profile,#{gmail_scopes}"
    else
      "/auth/google_oauth2"
    end
  end
end
