class ChangeBillingStatusToInteger < ActiveRecord::Migration[8.0]
  def up
    remove_column :accounts, :billing_status
    add_column :accounts, :billing_status, :integer, default: 0, null: false
    
    # Set billing_status to 1 for accounts with gmail permissions
    Account.where(has_gmail_permissions: true).update_all(billing_status: 1)
    
    # Set trial to start a month from now for all accounts
    Account.update_all(subscription_period_end: 1.month.from_now)
  end

  def down
    remove_column :accounts, :billing_status
    add_column :accounts, :billing_status, :string, default: "setup"
  end
end
