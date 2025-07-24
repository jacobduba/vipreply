class RenameStripeStatusToBillingStatus < ActiveRecord::Migration[8.0]
  def change
    rename_column :accounts, :stripe_status, :billing_status
  end
end
