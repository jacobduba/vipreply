class SetGmailPermissionsForExistingAccounts < ActiveRecord::Migration[8.0]
  def up
    # All existing accounts have Gmail permissions since it was required at signup
    Account.update_all(has_gmail_permissions: true)
  end
  
  def down
    # Can't reliably reverse this - some accounts may have legitimately false values
    # So we do nothing on rollback
  end
end
