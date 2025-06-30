# frozen_string_literal: true

module ApplicationHelper
  def google_oauth_url(prompt_consent: false, request_gmail_scopes: false, login_hint: nil)
    params = {}
    params[:prompt] = "consent" if prompt_consent
    params[:scope] = "email,profile,https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/gmail.send" if request_gmail_scopes
    params[:login_hint] = login_hint if login_hint.present?
    
    if params.any?
      "/auth/google_oauth2?#{params.to_query}"
    else
      "/auth/google_oauth2"
    end
  end
end
