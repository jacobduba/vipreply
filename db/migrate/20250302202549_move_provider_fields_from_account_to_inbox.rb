class MoveProviderFieldsFromAccountToInbox < ActiveRecord::Migration[8.0]
  def change
    # Add provider fields to Inbox
    add_column :inboxes, :provider, :string
    add_column :inboxes, :refresh_token, :string, limit: 1020
    add_column :inboxes, :access_token, :string, limit: 1020
    add_column :inboxes, :expires_at, :datetime
    
    # Add index for provider
    add_index :inboxes, [:account_id, :provider], unique: true
    
    # Set default provider for existing inboxes
    execute "UPDATE inboxes SET provider = 'google_oauth2'"
    
    # Make provider required
    change_column_null :inboxes, :provider, false, 'google_oauth2'
  end
end