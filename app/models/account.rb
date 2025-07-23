# frozen_string_literal: true

class Account < ApplicationRecord
  class NoGmailPermissionsError < StandardError; end

  has_one :inbox, dependent: :destroy

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: {scope: :provider}
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}

  encrypts :access_token
  encrypts :refresh_token

  attribute :input_token_usage, :integer, default: 0
  attribute :output_token_usage, :integer, default: 0
  attribute :has_gmail_permissions, :boolean, default: false

  enum billing_status: {
    setup: "setup",
    trialing: "trialing", 
    trial_expired: "trial_expired",
    active: "active",
    past_due: "past_due",
    unpaid: "unpaid",
    canceled: "canceled",
    incomplete: "incomplete",
    incomplete_expired: "incomplete_expired"
  }

  # Note on permissions
  # - If account is disconencted we we sign the person out and show error message
  # - If account doesnt have enough scopes we should the kinda oauth screen to prompt to grant permissions

  # Returns Google credentials for Gmail API operations
  # This method should only be called when has_gmail_permissions is true
  # Throws Google::Apis::AuthorizationError if tokens are invalid/revoked
  def google_credentials
    scopes = ["email", "profile"]
    if has_gmail_permissions
      scopes += ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
    end

    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      refresh_token: refresh_token,
      access_token: access_token,
      expires_at: expires_at,
      scope: scopes
    )

    # Refresh 10 seconds before expiration to avoid race conditions
    if expires_at < Time.current + 10.seconds
      credentials.refresh!
      update!(
        access_token: credentials.access_token,
        expires_at: credentials.expires_at
      )
    end

    credentials
  end

  def with_gmail_service
    raise NoGmailPermissionsError, "Account #{email} lacks Gmail permissions" unless has_gmail_permissions

    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = google_credentials

    yield service
  rescue Signet::AuthorizationError => e
    # Raised when refresh token is invalid/revoked (user disconnected app completely)
    Rails.logger.error "Refresh token revoked/invalid for #{email}: #{e.message}"
    update!(has_gmail_permissions: false)
    raise NoGmailPermissionsError, "Account #{email} lost Gmail permissions"
  rescue Google::Apis::AuthorizationError => e
    # Raised for 401 errors - may occur when user disconnects app
    Rails.logger.error "Authorization failed for #{email}: #{e.message}"
    update!(has_gmail_permissions: false)
    raise NoGmailPermissionsError, "Account #{email} lost Gmail permissions"
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

    with_gmail_service do |service|
      watch_request = Google::Apis::GmailV1::WatchRequest.new(
        label_ids: ["INBOX"],
        topic_name: Rails.application.credentials.gmail_topic_name
      )

      response = service.watch_user("me", watch_request)
      Rails.logger.info "Gmail watch started for #{email}, history_id: #{response.history_id}"
    end

    nil
  end

  def self.refresh_all_gmail_watches
    where(provider: "google_oauth2", has_gmail_permissions: true)
      .find_each do |account|
      # TODO add db attr to account
      # WHY? right now we have the provider: "google_oauth2".
      # cool if we could also do provider: "google_oauth2", subscribed: true
      # Instead of loading all accounts rn
      next unless account.has_access?

      Rails.error.handle do # just learned about this, lets u report error but doesnt stop the process
        account.refresh_gmail_watch
      end
    end
  end

  def has_access?
    trialing? || active?
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
