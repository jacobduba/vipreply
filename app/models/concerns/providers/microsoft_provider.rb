# app/models/concerns/providers/microsoft_provider.rb
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
      Rails.logger.info "Refreshing Microsoft token for inbox #{id}"

      if refresh_token.blank?
        raise "Missing refresh token for Microsoft inbox #{id}"
      end

      begin
        token = OAuth2::AccessToken.new(
          oauth2_client,
          access_token,
          refresh_token: refresh_token,
          expires_at: expires_at.to_i
        )

        new_token = token.refresh!

        Rails.logger.info "Successfully refreshed Microsoft token"

        # Log token info
        Rails.logger.info "New access token? #{new_token.token != access_token}"
        Rails.logger.info "New refresh token provided? #{new_token.refresh_token.present?}"
        Rails.logger.info "New expiry: #{Time.at(new_token.expires_at)}"

        update!(
          access_token: new_token.token,
          refresh_token: new_token.refresh_token || refresh_token,
          expires_at: Time.at(new_token.expires_at)
        )
      rescue OAuth2::Error => e
        Rails.logger.error "OAuth2 error refreshing Microsoft token: #{e.message}"
        Rails.logger.error "Error description: #{e.description}" if e.respond_to?(:description)
        Rails.logger.error "Response body: #{e.response.body}" if e.response
        raise
      rescue => e
        Rails.logger.error "Error refreshing Microsoft token: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        raise
      end
    end

    def watch_for_changes
      # Use BASE_URL environment variable, crucial for development with ngrok
      # In production, ensure this ENV variable is set to your app's public domain.
      base_url = ENV['BASE_URL']
      unless base_url.present?
        Rails.logger.error "MicrosoftProvider#watch_for_changes: BASE_URL environment variable not set. Cannot create webhook subscription for Inbox #{id}."
        return nil
      end

      # Generate the correct notification URL using the named route
      # Ensure host is provided, especially needed outside of request context.
      begin
        notification_url = Rails.application.routes.url_helpers.microsoft_webhook_callback_url(host: base_url)
        Rails.logger.info "MicrosoftProvider#watch_for_changes: Using notification URL: #{notification_url} for Inbox #{id}"
      rescue => e
        Rails.logger.error "MicrosoftProvider#watch_for_changes: Failed to generate notification URL for Inbox #{id}: #{e.message}"
        return nil
      end

      # Ensure a unique client state for this inbox if not present
      unless microsoft_client_state.present?
        update!(microsoft_client_state: SecureRandom.uuid)
        Rails.logger.info "MicrosoftProvider#watch_for_changes: Generated client state for Inbox #{id}: #{microsoft_client_state}"
      end

      # Define subscription details
      subscription_payload = {
        changeType: "created", # Only trigger on new messages initially? Or "created,updated"? Check Graph docs.
        notificationUrl: notification_url,
        resource: "/me/mailFolders('inbox')/messages", # More specific resource path
        expirationDateTime: (Time.now + 2.days + 23.hours).iso8601, # Max expiry is a bit less than 3 days
        clientState: microsoft_client_state # Use the stored client state
      }

      Rails.logger.info "MicrosoftProvider#watch_for_changes: Attempting to create/update subscription for Inbox #{id} with payload: #{subscription_payload.except(:clientState)}" # Don't log clientState

      begin
        # Ensure token is fresh before making the API call
        refresh_token! if expires_at.present? && expires_at < Time.current + 5.minutes

        response = graph_client.post("/v1.0/subscriptions") do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = subscription_payload.to_json
        end

        if response.success?
          subscription = response.body
          update!(microsoft_subscription_id: subscription["id"])
          Rails.logger.info "MicrosoftProvider#watch_for_changes: Successfully created/updated Microsoft subscription for Inbox #{id}. Subscription ID: #{subscription['id']}"
          return subscription # Return the subscription object
        else
          Rails.logger.error "MicrosoftProvider#watch_for_changes: Failed to create Microsoft subscription for Inbox #{id}. Status: #{response.status}, Body: #{response.body}"
          # Consider clearing microsoft_subscription_id if creation fails?
          # update!(microsoft_subscription_id: nil)
          return nil
        end
      rescue OAuth2::Error => e
        Rails.logger.error "MicrosoftProvider#watch_for_changes: OAuth error during token refresh or API call for Inbox #{id}: #{e.message}"
        return nil
      rescue Faraday::Error => e
        Rails.logger.error "MicrosoftProvider#watch_for_changes: Faraday error creating subscription for Inbox #{id}: #{e.message}"
        return nil
      rescue => e
        Rails.logger.error "MicrosoftProvider#watch_for_changes: Unexpected error creating subscription for Inbox #{id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return nil
      end
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
