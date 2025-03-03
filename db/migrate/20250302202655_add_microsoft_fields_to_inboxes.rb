class AddMicrosoftFieldsToInboxes < ActiveRecord::Migration[8.0]
  def change
    add_column :inboxes, :microsoft_subscription_id, :string
    add_column :inboxes, :microsoft_client_state, :string
    add_column :inboxes, :last_sync_time, :datetime
  end
end
