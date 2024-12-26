class RemoveColumnsFromAccounts < ActiveRecord::Migration[8.0]
  def change
    remove_column :accounts, :username, :string
    remove_column :accounts, :password_digest, :string
  end
end
