# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_forgery_protection # Disable CSRF protection for webhooks

  def stripe
    payload = request.body.read

    event = if Rails.env.development?
      json_event = JSON.parse(payload)
      Stripe::Event.construct_from(json_event)
    else
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      endpoint_secret = Rails.application.credentials.stripe_webhook_secret

      begin
        Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      rescue JSON::ParserError, Stripe::SignatureVerificationError
        render json: { error: "Invalid webhook" }, status: 400
        return
      end
    end

    Rails.error.set_context(
      stripe_event_type: event.type,
      stripe_customer_id: event.data.object.customer,
      event_data: event.to_hash
    )

    type = event.type
    object = event.data.object

    # Note: if you change these events you have to tell the dashboard to send those events
    case type
    when "customer.subscription.created", "customer.subscription.updated", "customer.subscription.deleted"
      handle_subscription_updated(object)
    when "customer.subscription.trial_will_end"
      Rails.logger.info "Trial ending soon for customer: #{object.customer}"
    else
      Rails.logger.info "Unhandled event type: #{type}"
    end

    render json: { status: "success" }
  end

  def gmail
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
      claim = Google::Auth::IDTokens.verify_oidc token, aud: "https://app.vipreply.ai/webhooks/gmail"

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

  private

  def handle_subscription_updated(subscription)
    customer_id = subscription.customer
    account = Account.find_by!(stripe_customer_id: customer_id)
    subscription_id = subscription.id

    # Get period end from first subscription item
    period_end = subscription.items.data.first.current_period_end
    stripe_status = subscription.status
    cancel_at_period_end = subscription.cancel_at_period_end

    # Don't update status for incomplete - it's just processing
    # apparently incomplete is for payments that take time
    # there are credit cards that do 2fa? so thats incomplete
    return if stripe_status == "incomplete"

    # Map Stripe subscription status to our integer enum
    billing_status = case stripe_status
    when "active" then :active
    when "past_due" then :past_due
    when "canceled" then :canceled
    when "incomplete_expired" then :canceled
    when "unpaid" then :suspended
    when "trialing" then :trialing
    else :setup
    end

    account.update!(
      billing_status: billing_status,
      stripe_subscription_id: subscription_id,
      cancel_at_period_end: cancel_at_period_end,
      subscription_period_end: Time.at(period_end)
    )
  end
end
