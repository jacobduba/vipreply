class AddMoreOauthToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :provider, :string
    add_column :accounts, :uid, :string
    add_column :accounts, :email, :string
    add_column :accounts, :name, :string
    add_column :accounts, :first_name, :string
    add_column :accounts, :last_name, :string
    add_column :accounts, :expires_at, :datetime
    add_index :accounts, [ :provider, :uid ], unique: true
  end
end
