class ModifyMessageIdConstraints < ActiveRecord::Migration[8.0]
  def up
    # First, remove the existing unique index on message_id
    remove_index :messages, :message_id if index_exists?(:messages, :message_id)

    # Add a compound index for message_id and topic_id
    # This allows the same message_id to exist in different topics/inboxes
    add_index :messages, [:message_id, :topic_id], unique: true, name: "index_messages_on_message_id_and_topic_id"
  end

  def down
    # Remove the compound index
    remove_index :messages, name: "index_messages_on_message_id_and_topic_id" if index_exists?(:messages, name: "index_messages_on_message_id_and_topic_id")

    # Restore the original index
    add_index :messages, :message_id, unique: true
  end
end
