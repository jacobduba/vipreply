module Providers
  module MicrosoftProvider
    extend ActiveSupport::Concern
    include BaseProvider

    def credentials
      OAuth2::AccessToken.new(
        oauth2_client,
        access_token,
        refresh_token: refresh_token,
        expires_at: expires_at.to_i
      )
    end

    def refresh_token!
      token = OAuth2::AccessToken.new(
        oauth2_client,
        access_token,
        refresh_token: refresh_token,
        expires_at: expires_at.to_i
      )

      new_token = token.refresh!

      update!(
        access_token: new_token.token,
        refresh_token: new_token.refresh_token || refresh_token,
        expires_at: Time.at(new_token.expires_at)
      )
    end

    def watch_for_changes
      return if Rails.env.development?

      # Generate a unique client state for this inbox if not present
      unless microsoft_client_state.present?
        update!(microsoft_client_state: SecureRandom.uuid)
      end

      # Create or update subscription
      notification_url = "#{Rails.application.routes.url_helpers.root_url}pubsub/notifications"

      response = graph_client.post("/subscriptions") do |req|
        req.body = {
          changeType: "created,updated",
          notificationUrl: notification_url,
          resource: "/users/me/mailFolders/inbox/messages",
          expirationDateTime: (Time.now + 3.days).iso8601,
          clientState: microsoft_client_state
        }
      end

      if response.success?
        subscription = response.body
        update!(microsoft_subscription_id: subscription["id"])
      else
        Rails.logger.error "Failed to create Microsoft subscription: #{response.body}"
      end
    rescue => e
      Rails.logger.error "Error setting up Microsoft subscription: #{e.message}"
      nil
    end

    # Graph API client methods
    def graph_client
      Faraday.new(url: "https://graph.microsoft.com") do |conn|
        conn.request :authorization, "Bearer", access_token
        conn.request :json
        conn.response :json
        conn.adapter Faraday.default_adapter
      end
    end

    def fetch_messages(limit = 50)
      response = graph_client.get("/v1.0/me/mailFolders/inbox/messages") do |req|
        req.params = {
          "$top": limit,
          "$orderby": "receivedDateTime desc",
          "$expand": "attachments"
        }
      end

      if response.success?
        response.body["value"]
      else
        Rails.logger.error "Error fetching Outlook messages: #{response.status} - #{response.body.inspect}"
        []
      end
    end

    def fetch_conversations(limit = 50)
      # First get messages
      messages = fetch_messages(limit)

      # Return early if no messages
      return [] if messages.blank?

      # Group by conversationId
      conversations = messages.group_by { |msg| msg["conversationId"] }

      # Format them for our application
      conversations.map do |id, msgs|
        {
          "id" => id,
          "messages" => msgs.sort_by { |msg| msg["receivedDateTime"] }
        }
      end
    end

    private

    def oauth2_client
      @oauth2_client ||= OAuth2::Client.new(
        Rails.application.credentials.microsoft_client_id,
        Rails.application.credentials.microsoft_client_secret,
        site: "https://login.microsoftonline.com",
        token_url: "/common/oauth2/v2.0/token"
      )
    end
  end
end
