# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_forgery_protection # Disable CSRF protection for webhookn

  def stripe
    payload = request.body.read

    event = if Rails.env.development?
      JSON.parse(payload)
    else
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      endpoint_secret = Rails.application.credentials.stripe_webhook_secret

      begin
        Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      rescue JSON::ParserError, Stripe::SignatureVerificationError
        render json: {error: "Invalid webhook"}, status: 400
        return
      end
    end

    case event["type"]
    when "checkout.session.completed"
      handle_checkout_completed(event["data"]["object"])
    when "invoice.payment_succeeded"
      handle_payment_succeeded(event["data"]["object"])
    when "invoice.payment_failed"
      handle_payment_failed(event["data"]["object"])
    when "customer.subscription.updated"
      handle_subscription_updated(event["data"]["object"])
    when "customer.subscription.deleted"
      handle_subscription_deleted(event["data"]["object"])
    else
      Rails.logger.info "Unhandled event type: #{event["type"]}"
    end

    render json: {status: "success"}
  end

  private

  def handle_checkout_completed(session)
    customer_id = session["customer"]
    subscription_id = session["subscription"]
    account = Account.find_by!(stripe_customer_id: customer_id)

    # Fetch subscription to get period end
    subscription = Stripe::Subscription.retrieve(subscription_id)
    period_end = subscription.items.data.first.current_period_end

    account.update!(
      stripe_status: subscription.status,
      stripe_subscription_id: subscription_id,
      subscription_period_end: Time.at(period_end),
      cancel_at_period_end: false
    )

    # Setup inbox for first-time subscribers, import for returning users
    if account.inbox.history_id.present?
      # Returning user - import emails since last history_id
      UpdateFromHistoryJob.perform_later(account.inbox.id)
    else
      # First-time user - setup Gmail watch and get initial history_id
      SetupInboxJob.perform_later(account.id)
    end
  end

  def handle_payment_succeeded(invoice)
    customer_id = invoice["customer"]
    subscription_id = invoice["subscription"]
    account = Account.find_by!(stripe_customer_id: customer_id)

    # Fetch subscription to get updated period end
    subscription = Stripe::Subscription.retrieve(subscription_id)
    period_end = subscription.items.data.first.current_period_end

    account.update!(
      stripe_status: subscription.status,
      stripe_subscription_id: subscription_id,
      subscription_period_end: Time.at(period_end)
    )
  end

  def handle_payment_failed(invoice)
    customer_id = invoice["customer"]
    account = Account.find_by!(stripe_customer_id: customer_id)

    account.update!(stripe_status: "past_due")
  end

  def handle_subscription_updated(subscription)
    customer_id = subscription["customer"]
    account = Account.find_by!(stripe_customer_id: customer_id)

    # Get period end from first subscription item
    period_end = subscription["items"]["data"].first["current_period_end"]

    account.update!(
      stripe_status: subscription["status"],
      subscription_period_end: Time.at(period_end),
      cancel_at_period_end: subscription["cancel_at_period_end"]
    )
  end

  def handle_subscription_deleted(subscription)
    customer_id = subscription["customer"]
    account = Account.find_by!(stripe_customer_id: customer_id)

    account.update!(stripe_status: "cancelled")
  end
end
