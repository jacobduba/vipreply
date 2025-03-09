class AddSecondaryEmailToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :secondary_emails, :string, array: true, default: []
  end
end
