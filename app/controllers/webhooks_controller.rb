# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_forgery_protection # Disable CSRF protection for webhooks

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

    # Note: if you change these events you have to tell the dashboard to send those events
    case type
    when "invoice.paid"
      handle_invoice_paid(object)
    when "customer.subscription.updated"
      handle_subscription_updated(object)
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
    account = Account.find_by!(stripe_customer_id: customer_id)

    invoice_item = invoice["lines"]["data"].first
    stripe_status = invoice["status"]
    subscription_id = invoice_item["parent"]["subscription_item_details"]["subscription"]
    period_end = invoice_item["period"]["end"]

    # Map Stripe status to our integer enum
    billing_status = case stripe_status
    when "paid" then :active
    when "open" then :past_due
    else :active # default for paid invoices
    end

    account.update!(
      billing_status: billing_status,
      stripe_subscription_id: subscription_id,
      access_period_end: Time.at(period_end),
      cancel_at_period_end: false
    )

    # Can assume if you are paying you have setup inbox because comes with free trial
    UpdateFromHistoryJob.perform_later(account.inbox.id)
  end

  def handle_subscription_updated(subscription)
    customer_id = subscription["customer"]
    account = Account.find_by!(stripe_customer_id: customer_id)

    # Get period end from first subscription item
    period_end = subscription["items"]["data"].first["current_period_end"]
    stripe_status = subscription["status"]
    cancel_at_period_end = subscription["cancel_at_period_end"]

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
      cancel_at_period_end: cancel_at_period_end,
      access_period_end: Time.at(period_end)
    )
  end
end
