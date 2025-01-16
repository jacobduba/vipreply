class AddTokensToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :access_token, :string
    add_column :accounts, :refresh_token, :string
    remove_column :inboxes, :access_token
    remove_column :inboxes, :refresh_token
  end
end
