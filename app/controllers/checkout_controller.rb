# frozen_string_literal: true

class CheckoutController < ApplicationController
  before_action :authorize_account
  def subscribe
    # Get or create Stripe customer
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

    # Create checkout session
    # When developing, test with fake cards from https://docs.stripe.com/testing
    session = Stripe::Checkout::Session.create({
      customer: customer_id,
      line_items: [{
        price: price_id,
        quantity: 1
      }],
      mode: "subscription",
      subscription_data: {
        trial_period_days: 30
      },
      success_url: checkout_success_url,
      cancel_url: checkout_cancel_url
    })

    # Set status to track checkout attempt
    @account.update!(stripe_status: "incomplete")

    redirect_to session.url, allow_other_host: true
  end

  def success
  end

  def cancel
    redirect_to inbox_path
  end
end
