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
    billing_status = invoice["status"]
    subscription_id = invoice_item["parent"]["subscription_item_details"]["subscription"]
    period_end = invoice_item["period"]["end"]

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
    billing_status = subscription["status"]
    cancel_at_period_end = subscription["cancel_at_period_end"]

    account.update!(
      billing_status: billing_status,
      cancel_at_period_end: cancel_at_period_end,
      access_period_end: Time.at(period_end)
    )
  end
end
