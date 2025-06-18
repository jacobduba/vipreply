class AddTokenUsageToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :input_token_usage, :integer, default: 0
    add_column :accounts, :output_token_usage, :integer, default: 0
  end
end
