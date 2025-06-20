# frozen_string_literal: true

class PubsubController < ApplicationController
  skip_forgery_protection # Disable CSRF protection for webhook

  def notifications
    # Setting up Gmail webhook:
    # 1. Follow webhook setup: https://developers.google.com/gmail/api/guides/push
    # 2. Enable authentication: https://cloud.google.com/pubsub/docs/authenticate-push-subscriptions#console
    #    - First create a service account: https://console.cloud.google.com/iam-admin/serviceaccounts
    #      (Name it "gmail-webhook-verifier", no roles needed)
    #    - Then follow the authentication guide using that service account
    #
    # TODO: Add webhook authentication verification here
    #
    # Decode the Pub/Sub message
    message = params[:message][:data]
    message = JSON.parse(Base64.decode64(message))

    # Extract email and history ID
    email = message["emailAddress"]
    history_id = message["historyId"]

    # Track webhook in Honeybadger Insights for debugging
    Honeybadger.event(
      event_type: "gmail_webhook_received",
      email: email,
      history_id: history_id,
      raw_payload: params.to_unsafe_h
    )

    # Find the account by email and use the associated inbox
    account = Account.find_by(email: email)

    if account&.inbox && account.subscribed?
      UpdateFromHistoryJob.perform_later account.inbox.id
    end

    head :ok
  end
end
