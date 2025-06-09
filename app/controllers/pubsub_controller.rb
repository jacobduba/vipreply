class PubsubController < ApplicationController
  skip_forgery_protection # Disable CSRF protection for webhook

  def notifications
    # Decode the Pub/Sub message
    message = params[:message][:data]
    message = JSON.parse(Base64.decode64(message))

    # Extract email and history ID
    email = message["emailAddress"]
    history_id = message["historyId"]

    # Find the account by email and use the associated inbox
    account = Account.find_by(email: email)

    if account&.inbox && account.subscribed?
      UpdateFromHistoryJob.perform_later account.inbox.id
    end

    head :ok
  end
end
