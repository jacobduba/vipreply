# app/controllers/pubsub_controller.rb
class PubsubController < ApplicationController
  skip_before_action :authorize_account
  skip_forgery_protection

  def notifications
    Rails.logger.info "Received Pub/Sub notification"

    # Decode the Pub/Sub message
    message = params[:message][:data]
    message = JSON.parse(Base64.decode64(message))

    # Extract email and history ID
    email = message["emailAddress"]
    history_id = message["historyId"]

    Rails.logger.info "Received notification for email: #{email}, history ID: #{history_id}"

    # Find the account by email and use the associated inbox
    account = Account.find_by(email: email)
    if account&.inbox
      UpdateFromHistoryJob.perform_later account.inboxes.first.id
    else
      Rails.logger.error "Account or inbox not found for email: #{email}"
    end

    head :ok
  end

  def microsoft_notifications
    # --- Handle Validation Request ---
    validation_token = params[:validationToken]
    if validation_token.blank? && request.content_length.to_i > 0
      request.body.rewind
      body_content = request.body.read
      if body_content.length > 10 && body_content.match?(/\A[a-zA-Z0-9+_\-=]+\z/)
         validation_token = body_content
      else
        begin
          parsed_body = JSON.parse(body_content)
          validation_token = parsed_body['validationToken'] if parsed_body.is_a?(Hash)
        rescue JSON::ParserError
          # Ignore if body isn't valid JSON
        end
      end
    end

    if validation_token.present?
      Rails.logger.info "Microsoft Webhook Validation Request Received."
      render plain: validation_token, status: :ok, content_type: 'text/plain'
      return
    end

    # --- Handle Actual Change Notification ---
    Rails.logger.info "Microsoft Change Notification Received."
    begin
      request.body.rewind
      notification_data = JSON.parse(request.body.read)
      notifications = notification_data['value']

      unless notifications.is_a?(Array) && notifications.first.is_a?(Hash)
         Rails.logger.warn "Microsoft notification data invalid format. Data: #{notification_data.inspect}"
         head :accepted
         return
      end

      first_notification = notifications.first
      client_state = first_notification['clientState']

      unless client_state.present?
          Rails.logger.warn "Microsoft notification received without 'clientState'. Payload: #{first_notification.inspect}"
          head :accepted
          return
      end

      inbox = Inbox.find_by(microsoft_client_state: client_state)
      unless inbox
        Rails.logger.error "No inbox found with client state: #{client_state}. Ignoring notification."
        head :accepted
        return
      end

      job_enqueued = false
      notifications.each do |notification|
        change_type = notification['changeType']
        resource = notification['resource']

        Rails.logger.info "Processing notification for Inbox #{inbox.id}: changeType=#{change_type}, resource=#{resource&.truncate(100)}" # Truncate resource for logs

        # Use case-insensitive check for '/messages'
        if resource&.downcase&.include?('/messages') && (change_type == 'created' || change_type == 'updated')
          unless job_enqueued
            Rails.logger.info "Change detected for messages in Inbox #{inbox.id}. Enqueuing UpdateFromHistoryJob."
            UpdateFromHistoryJob.perform_later(inbox.id)
            job_enqueued = true
          end
        else
            Rails.logger.info "Ignoring notification type '#{change_type}' for resource for Inbox #{inbox.id}."
        end
      end

      unless job_enqueued
        Rails.logger.warn "UpdateFromHistoryJob was NOT enqueued for this webhook call for Inbox #{inbox.id}."
      end

      Rails.logger.info "Finished processing notification batch for Inbox #{inbox.id}."

    rescue JSON::ParserError => e
      Rails.logger.error "Error parsing Microsoft notification JSON: #{e.message}"
      head :accepted
    rescue => e
      Rails.logger.error "Error processing Microsoft notification: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n") # Log first few lines of backtrace
      head :accepted
    end

    head :accepted unless performed?
  end
end
