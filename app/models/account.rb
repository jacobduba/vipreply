# frozen_string_literal: true

class Account < ApplicationRecord
  has_and_belongs_to_many :models
  has_one :inbox, dependent: :destroy
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: {scope: :provider}
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  encrypts :access_token
  encrypts :refresh_token

  # Throws Signet::AuthorizationError
  def refresh_google_token!
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      refresh_token: refresh_token,
      scope: ["email", "profile", "https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
    )

    credentials.refresh!

    update!(
      access_token: credentials.access_token,
      expires_at: credentials.expires_at
    )
  end

  def google_credentials
    Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      refresh_token: refresh_token,
      access_token: access_token,
      expires_at: expires_at,
      scope: ["email", "profile", "https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
    )
  end

  def refresh_gmail_watch
    # Documentation for setting this up in Cloud Console
    # https://developers.google.com/gmail/api/guides/push

    return unless provider == "google_oauth2"

    if Rails.env.development?
      Rails.logger.info "[DEV MODE] Would refresh Gmail watch for #{email}"
      return
    end

    Rails.logger.info "Setting up Gmail watch for #{email}"

    unless inbox.present?
      Rails.logger.error "Inbox not found for account #{email}."
      return
    end

    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = google_credentials

    watch_request = Google::Apis::GmailV1::WatchRequest.new(
      label_ids: ["INBOX"],
      topic_name: Rails.application.credentials.gmail_topic_name
    )

    begin
      response = gmail_service.watch_user("me", watch_request)
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Failed to start Gmail watch for #{email}: #{e.message}"
      nil
    end

    Rails.logger.info "Gmail watch started for #{email}, history_id: #{response.history_id}"
    response
  end

  def self.refresh_all_gmail_watches
    where(provider: "google_oauth2")
      .select(:id, :email, :access_token, :refresh_token, :expires_at, :provider)
      .find_each do |account|
      account.refresh_gmail_watch
    rescue => e
      Rails.logger.error "Failed to refresh Gmail watch for #{account.email}: #{e.message}"
    end
  end

  def subscribed?
    stripe_status == "active" || stripe_status == "trialing"
  end

  def to_honeybadger_context
    {
      id: id,
      uid: uid,
      email: email,
      name: name,
      provider: provider,
      token_expires_at: expires_at
    }
  end
end
