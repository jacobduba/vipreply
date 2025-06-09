class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authorize_account

  # Disable CSRF protection for webhook
  skip_forgery_protection

  def stripe
    payload = request.body.read

    event = if Rails.env.development?
      JSON.parse(payload)
    else
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      endpoint_secret = Rails.application.credentials.stripe_webhook_secret

      begin
        Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      rescue JSON::ParserError, Stripe::SignatureVerificationError => e
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
    account = Account.find_by(stripe_customer_id: customer_id)
    return unless account

    # Fetch subscription to get period end
    subscription = Stripe::Subscription.retrieve(subscription_id)
    period_end = subscription.items.data.first.current_period_end

    account.update!(
      stripe_status: subscription.status,
      stripe_subscription_id: subscription_id,
      subscription_period_end: Time.at(period_end)
    )

    # Start inbox setup for new subscribers
    SetupInboxJob.perform_later(account.id)
  end

  def handle_payment_succeeded(invoice)
    customer_id = invoice["customer"]
    subscription_id = invoice["subscription"]
    account = Account.find_by(stripe_customer_id: customer_id)
    return unless account

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
    account = Account.find_by(stripe_customer_id: customer_id)
    return unless account

    account.update!(stripe_status: "past_due")
  end

  def handle_subscription_deleted(subscription)
    customer_id = subscription["customer"]
    account = Account.find_by(stripe_customer_id: customer_id)
    return unless account

    account.update!(stripe_status: "cancelled")
  end
end
