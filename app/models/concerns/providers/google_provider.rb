module Providers
  module GoogleProvider
    extend ActiveSupport::Concern
    include BaseProvider

    def credentials
      Google::Auth::UserRefreshCredentials.new(
        client_id: Rails.application.credentials.google_client_id,
        client_secret: Rails.application.credentials.google_client_secret,
        refresh_token: refresh_token,
        access_token: access_token,
        expires_at: expires_at,
        scope: ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
      )
    end

    def refresh_token!
      creds = Google::Auth::UserRefreshCredentials.new(
        client_id: Rails.application.credentials.google_client_id,
        client_secret: Rails.application.credentials.google_client_secret,
        refresh_token: refresh_token,
        scope: ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
      )

      creds.refresh!

      update!(
        access_token: creds.access_token,
        expires_at: creds.expires_at
      )
    end

    def watch_for_changes
      return if Rails.env.development?

      gmail_service = Google::Apis::GmailV1::GmailService.new
      gmail_service.authorization = credentials

      watch_request = Google::Apis::GmailV1::WatchRequest.new(
        label_ids: ["INBOX"],
        topic_name: Rails.application.credentials.gmail_topic_name
      )

      response = gmail_service.watch_user("me", watch_request)
      update!(history_id: response.history_id.to_i) if response.history_id

      response
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Failed to watch for changes: #{e.message}"
      nil
    end

    def gmail_service
      service = Google::Apis::GmailV1::GmailService.new
      service.authorization = credentials
      service
    end
  end
end
