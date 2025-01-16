class AddGmailMessageIdToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :gmail_message_id, :string, limit: 64
    add_index :messages, :message_id, unique: true
  end
end
