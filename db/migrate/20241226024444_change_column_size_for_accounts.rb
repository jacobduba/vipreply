class ChangeColumnSizeForAccounts < ActiveRecord::Migration[8.0]
  def up
    change_column :accounts, :access_token, :string, limit: 1020
    change_column :accounts, :refresh_token, :string, limit: 1020
  end

  def down
    change_column :accounts, :access_token, :string, limit: 255
    change_column :accounts, :refresh_token, :string, limit: 255
  end
end
