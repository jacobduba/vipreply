class RemoveTokenUsageFromAccounts < ActiveRecord::Migration[8.0]
  def change
    remove_column :accounts, :input_token_usage, :integer
    remove_column :accounts, :output_token_usage, :integer
  end
end
