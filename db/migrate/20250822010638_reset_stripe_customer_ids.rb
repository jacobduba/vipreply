class ResetStripeCustomerIds < ActiveRecord::Migration[8.0]
  def up
    Account.update_all(
      stripe_customer_id: nil,
      stripe_subscription_id: nil
    )
  end

  def down
    # Cannot restore original values
  end
end
