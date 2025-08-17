class ChangeMessageIdUniqueConstraint < ActiveRecord::Migration[8.0]
  def change
    remove_index :messages, :message_id
    add_index :messages, [:message_id, :topic_id], unique: true
  end
end
