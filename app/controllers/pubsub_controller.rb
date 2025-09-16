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

    # Track webhook in Honeybadger Insights for debugging

    # Authenticate on prod
    if Rails.env.production?
      # Not handling errors to alert me when authorization fails
      bearer = request.headers["Authorization"]
      token = /Bearer (.*)/.match(bearer)[1]
      claim = Google::Auth::IDTokens.verify_oidc token, aud: "https://app.vipreply.ai/pubsub/notifications"

      unless claim["email"] == Rails.application.credentials.pubsub_service_account && claim["email_verified"] == true
        raise "Webhook authentication failed - unexpected service account #{claim["email"]}"
      end
    end

    # Decode the Pub/Sub message
    message = params[:message][:data]
    message = JSON.parse(Base64.decode64(message))

    # Extract email and history ID
    email = message["emailAddress"]

    # Find the account by email and use the associated inbox
    account = Account.find_by(email: email)

    if account&.inbox && account.has_access?
      UpdateFromHistoryJob.perform_later account.inbox.id
    end

    head :ok
  end
end
