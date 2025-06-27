class RenameHasOauthPermissionsToHasGmailPermissions < ActiveRecord::Migration[8.0]
  def change
    rename_column :accounts, :has_oauth_permissions, :has_gmail_permissions
  end
end
