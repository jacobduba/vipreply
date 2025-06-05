class AddStripeFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :stripe_customer_id, :string
    add_column :accounts, :stripe_subscription_id, :string
    add_column :accounts, :stripe_status, :string
    add_column :accounts, :subscription_period_end, :datetime
  end
end
