class GiveExistingUsersTrialAndResetStripe < ActiveRecord::Migration[8.0]
  def up
    # Give all existing users a 30-day trial starting today
    # and reset ALL Stripe info for EVERYONE
    Account.update_all(
      billing_status: 'trialing',
      subscription_period_end: 30.days.from_now,
      stripe_customer_id: nil,
      stripe_subscription_id: nil,
      cancel_at_period_end: false
    )
  end

  def down
    # Can't easily reverse this migration
    raise ActiveRecord::IrreversibleMigration
  end
end
