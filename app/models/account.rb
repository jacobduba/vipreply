# frozen_string_literal: true

class Account < ApplicationRecord
  has_and_belongs_to_many :models
  has_one :inbox, dependent: :destroy
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: {scope: :provider}
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  encrypts :access_token
  encrypts :refresh_token

  # Will have to do this with auth
  def refresh_google_token!
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      refresh_token: refresh_token,
      scope: ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
    )

    begin
      credentials.refresh!
    rescue Signet::AuthorizationError
      # Clear refresh token
      update!(refresh_token: nil)
      return false
    end

    update!(
      access_token: credentials.access_token,
      token_expiry: credentials.expires_at
    )
  end

  def google_credentials
    Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      refresh_token: refresh_token,
      access_token: access_token,
      expires_at: expires_at,
      scope: ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
    )
  end

  def setup_gmail_watch
    return unless provider == "google" && google_credentials.present?

    Rails.logger.info "Setting up Gmail watch for #{email}"

    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = google_credentials

    watch_request = Google::Apis::GmailV1::WatchRequest.new(
      label_ids: ["INBOX"],
      topic_name: "projects/emailthingy-445622/topics/gmail-updates"
    )

    begin
      response = gmail_service.watch("me", watch_request)
      update!(history_id: response.history_id)
      Rails.logger.info "Gmail watch started for #{email}, history_id: #{response.history_id}"
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Failed to start Gmail watch for #{email}: #{e.message}"
    end
  end
end
