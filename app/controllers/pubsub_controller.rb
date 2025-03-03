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
    # Check if this is a subscription validation request
    if request.headers["Content-Type"] == "text/plain"
      validation_token = request.body.read
      render plain: validation_token, content_type: "text/plain"
      return
    end

    client_state = request.headers["Client-State"]
    inbox = Inbox.find_by(microsoft_client_state: client_state)

    unless inbox
      Rails.logger.error "No inbox found with client state: #{client_state}"
      head :ok
      return
    end

    # Process the notification
    begin
      notification_data = JSON.parse(request.body.read)
      # Microsoft sends an array of notifications
      notification_data["value"].each do |notification|
        if notification["resourceData"]
          # A message was changed - trigger inbox update
          UpdateFromHistoryJob.perform_later inbox.id
        end
      end
    rescue => e
      Rails.logger.error "Error processing Microsoft notification: #{e.message}"
    end

    head :ok
  end
end
