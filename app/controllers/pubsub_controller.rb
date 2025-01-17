class PubsubController < ApplicationController
  skip_before_action :authorize_account
  # Disable CSRF protection for webhook
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
      UpdateFromHistoryJob.perform_later account.inbox.id
    else
      Rails.logger.error "Account or inbox not found for email: #{email}"
    end

    head :ok
  end
end
