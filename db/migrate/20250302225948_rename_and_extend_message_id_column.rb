class RenameAndExtendMessageIdColumn < ActiveRecord::Migration[8.0]
  def change
    rename_column :messages, :gmail_message_id, :provider_message_id

    change_column :messages, :provider_message_id, :text
  end
end
