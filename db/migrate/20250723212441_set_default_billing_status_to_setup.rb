class SetDefaultBillingStatusToSetup < ActiveRecord::Migration[8.0]
  def change
    change_column_default :accounts, :billing_status, "setup"
  end
end
