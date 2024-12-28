class RemoveInboxIdFromAccounts < ActiveRecord::Migration[8.0]
  def change
    remove_index :accounts, :inbox_id if index_exists?(:accounts, :inbox_id)
    remove_column :accounts, :inbox_id, :bigint
  end
end
