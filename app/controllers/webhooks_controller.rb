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

    Rails.error.set_context(event: JSON.pretty_generate(event))

    type = event["type"]
    object = event["data"]["object"]

    case type
    when "invoice.paid"
      handle_invoice_paid(object)
    when "invoice.payment_failed"
      handle_payment_failed(object)
    when "customer.subscription.updated"
      handle_subscription_updated(object)
    when "customer.subscription.deleted"
      handle_subscription_deleted(object)
    else
      Rails.logger.info "Unhandled event type: #{type}"
    end

    render json: {status: "success"}
  end

  private

  # We can assume they are paying for the One Subscription
  # that VIPReply offers
  def handle_invoice_paid(invoice)
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

    # Setup inbox for first-time subscribers, import for returning users
    if account.inbox.history_id.present?
      # Returning user - import emails since last history_id
      UpdateFromHistoryJob.perform_later(account.inbox.id)
    else
      # First-time user - setup Gmail watch and get initial history_id
      SetupInboxJob.perform_later(account.id)
    end
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
