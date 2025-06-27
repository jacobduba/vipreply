class AddHasOAuthPermissionsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :has_oauth_permissions, :boolean, default: false
  end
end
