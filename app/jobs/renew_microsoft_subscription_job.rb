class RenewMicrosoftSubscriptionsJob < ApplicationJob
  queue_as :default

  # Set a new expiration ~3 days from now
  NEW_EXPIRY_DURATION = 2.days + 23.hours

  def perform(*args)
    Rails.logger.info "Starting RenewMicrosoftSubscriptionsJob..."
    processed_count = 0
    renewed_count = 0
    failed_count = 0
    not_found_count = 0

    # Find Microsoft inboxes that have a subscription ID stored
    inboxes_to_renew = Inbox.where(provider: 'microsoft_office365').where.not(microsoft_subscription_id: [nil, ''])

    inboxes_to_renew.find_each do |inbox|
      processed_count += 1
      subscription_id = inbox.microsoft_subscription_id
      Rails.logger.info "RenewMicrosoftSubscriptionsJob: Checking subscription #{subscription_id} for Inbox #{inbox.id}"

      begin
        # Ensure token is valid before making the API call
        if inbox.expires_at.present? && inbox.expires_at < Time.current + 5.minutes
          Rails.logger.info "RenewMicrosoftSubscriptionsJob: Refreshing token for Inbox #{inbox.id} before renewal."
          inbox.refresh_token!
        end

        # Calculate new expiration time
        new_expiration_time = (Time.now + NEW_EXPIRY_DURATION).iso8601
        renewal_payload = {
          expirationDateTime: new_expiration_time
        }

        Rails.logger.info "RenewMicrosoftSubscriptionsJob: Attempting to renew subscription #{subscription_id} for Inbox #{inbox.id} to expire at #{new_expiration_time}"

        # Make the PATCH request to Microsoft Graph API
        response = inbox.graph_client.patch("/v1.0/subscriptions/#{subscription_id}") do |req|
           req.headers['Content-Type'] = 'application/json'
           req.body = renewal_payload.to_json
        end

        if response.success?
          Rails.logger.info "RenewMicrosoftSubscriptionsJob: Successfully renewed subscription #{subscription_id} for Inbox #{inbox.id}"
          renewed_count += 1
        else
          # Handle specific errors from the API response
          error_body = response.body || {}
          error_code = error_body.dig("error", "code")

          # If subscription is gone on Microsoft's side, remove it locally
          if response.status == 404 || error_code == 'ResourceNotFound'
            Rails.logger.warn "RenewMicrosoftSubscriptionsJob: Subscription #{subscription_id} for Inbox #{inbox.id} not found on Microsoft Graph. Clearing local ID."
            inbox.update!(microsoft_subscription_id: nil, microsoft_client_state: nil) # Clear state too
            not_found_count += 1
          else
            Rails.logger.error "RenewMicrosoftSubscriptionsJob: Failed to renew subscription #{subscription_id} for Inbox #{inbox.id}. Status: #{response.status}, Body: #{response.body}"
            failed_count += 1
          end
        end

      rescue OAuth2::Error => e
        Rails.logger.error "RenewMicrosoftSubscriptionsJob: OAuth error processing Inbox #{inbox.id} (Sub: #{subscription_id}): #{e.message}"
        failed_count += 1
      rescue Faraday::Error => e
        Rails.logger.error "RenewMicrosoftSubscriptionsJob: Faraday error processing Inbox #{inbox.id} (Sub: #{subscription_id}): #{e.message}"
        failed_count += 1
      rescue => e
        Rails.logger.error "RenewMicrosoftSubscriptionsJob: Unexpected error processing Inbox #{inbox.id} (Sub: #{subscription_id}): #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        failed_count += 1
      end
    end

    Rails.logger.info "Finished RenewMicrosoftSubscriptionsJob. Processed: #{processed_count}, Renewed: #{renewed_count}, Not Found: #{not_found_count}, Failed: #{failed_count}"
  end
end