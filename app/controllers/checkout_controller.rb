# frozen_string_literal: true

class CheckoutController < ApplicationController
  before_action :authorize_account

  def plans
  end

  def subscribe
    if @account.stripe_customer_id.present?
      customer_id = @account.stripe_customer_id
    else
      customer = Stripe::Customer.create({
        email: @account.email,
        name: @account.name
      })
      @account.update!(stripe_customer_id: customer.id)
      customer_id = customer.id
    end

    price_id = Rails.application.credentials.stripe_price_id

    # Use billing_cycle_anchor for users with trial/active access to defer payment
    subscription_data = if @account.has_access? && @account.subscription_period_end&.future? # Account access only updates every five minutes, so if <5 minutes over subscription period end can be negative which causes stripe error
      {
        billing_cycle_anchor: @account.subscription_period_end.to_i,
        proration_behavior: "none"
      }
    else
      {}
    end

    # Create checkout session
    # When developing, test with fake cards from https://docs.stripe.com/billing/quickstart?client=html#testing
    session = Stripe::Checkout::Session.create({
      customer: customer_id,
      line_items: [{
        price: price_id,
        quantity: 1
      }],
      mode: "subscription",
      subscription_data: subscription_data,
      payment_method_types: ["card"],
      success_url: checkout_success_url,
      cancel_url: checkout_cancel_url
    })

    redirect_to session.url, allow_other_host: true
  end

  def success
  end

  def cancel
    redirect_to inbox_path
  end
end
