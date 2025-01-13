class PubsubController < ApplicationController
  skip_before_action :verify_authenticity_token

  def notifications
    debugger

    # Decode the Pub/Sub message
    message = params[:message][:data]

    # Extract email and history ID
    email = message["emailAddress"]
    history_id = message["historyId"]

    Rails.logger.info "Received notification for email: #{email}, history ID: #{history_id}"

    # Process the notification
    inbox = Inbox.find_by(email: email)
    if inbox
      UpdateFromHistoryJob.perform_later inbox.id
    else
      Rails.logger.error "Inbox not found for email: #{email}"
    end

    head :ok
  end
end
