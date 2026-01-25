class RemoveSessionCountFromAccounts < ActiveRecord::Migration[8.0]
  def change
    remove_column :accounts, :session_count, :integer, default: 1
  end
end
