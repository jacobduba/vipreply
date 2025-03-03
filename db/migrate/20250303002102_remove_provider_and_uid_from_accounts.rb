class RemoveProviderAndUidFromAccounts < ActiveRecord::Migration[6.1]
  def change
    remove_index :accounts, column: [:provider, :uid] if index_exists?(:accounts, [:provider, :uid])
    remove_column :accounts, :provider, :string
    remove_column :accounts, :uid, :string
  end
end
