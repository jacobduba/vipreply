# app/models/account.rb
class Account < ApplicationRecord
  has_many :inboxes, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_and_belongs_to_many :models
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  encrypts :access_token
  encrypts :refresh_token

  # Helper method to check if an email belongs to this account
  def owns_email?(email_address)
    return false if email_address.blank?

    normalized_email = email_address.downcase.strip
    normalized_primary = email.downcase.strip

    return true if normalized_email == normalized_primary
    return secondary_emails.any? { |sec| sec.downcase.strip == normalized_email } if secondary_emails.present?

    false
  end

  # Get all email addresses for this account
  def all_emails
    [email] + (secondary_emails || [])
  end

  # Throws Signet::AuthorizationError
  def refresh_google_token!
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      refresh_token: refresh_token,
      scope: ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
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
      scope: ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
    )
  end

  def refresh_gmail_watch(inbox)
    # Check that inbox provider is google_oauth2
    return unless inbox.provider == "google_oauth2"

    if Rails.env.development?
      Rails.logger.info "[DEV MODE] Would refresh Gmail watch for #{email}"
      return
    end

    Rails.logger.info "Setting up Gmail watch for #{email}"

    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = inbox.credentials

    watch_request = Google::Apis::GmailV1::WatchRequest.new(
      label_ids: ["INBOX"],
      topic_name: Rails.application.credentials.gmail_topic_name
    )

    begin
      response = gmail_service.watch_user("me", watch_request)
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Failed to start Gmail watch for #{email}: #{e.message}"
      return nil
    end

    Rails.logger.info "Gmail watch started for #{email}, history_id: #{response.history_id}"
    response
  end

  def self.refresh_all_gmail_watches
    # Update to work with inboxes
    Inbox.where(provider: "google_oauth2").find_each do |inbox|
      inbox.watch_for_changes
    rescue => e
      Rails.logger.error "Failed to refresh Gmail watch for #{inbox.account.email}: #{e.message}"
    end
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
