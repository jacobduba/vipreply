# frozen_string_literal: true

class SettingsController < ApplicationController
  before_action :authorize_account

  def index
  end

  def cancel_subscription
    return unless @account.stripe_subscription_id

    # Cancel at period end to maintain access until paid period expires
    Stripe::Subscription.update(
      @account.stripe_subscription_id,
      { cancel_at_period_end: true }
    )

    @account.update!(cancel_at_period_end: true)

    redirect_to settings_path, notice: "Subscription cancelled. Access continues until #{@account.subscription_period_end.strftime('%B %d, %Y')}."
  end
end