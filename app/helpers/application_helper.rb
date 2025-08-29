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

  def confidence_badge_classes(confidence_score)
    confidence = confidence_score
    if confidence >= 0.95
      "inline-flex items-center rounded-sm bg-green-100/50 px-2 py-1 text-xs font-medium text-green-800 ring-1 ring-inset ring-green-600/20"
    elsif confidence >= 0.90
      "inline-flex items-center rounded-sm bg-green-50/50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20"
    elsif confidence >= 0.80
      "inline-flex items-center rounded-sm bg-yellow-50/80 px-2 py-1 text-xs font-medium text-yellow-700 ring-1 ring-inset ring-yellow-600/20"
    else
      "inline-flex items-center rounded-full bg-red-50/50 px-2 py-1 text-xs font-medium text-red-700/80 ring-1 ring-inset ring-red-600/5"
    end
  end

  def confidence_percentage(confidence_score)
    (confidence_score * 100).round
  end
end
