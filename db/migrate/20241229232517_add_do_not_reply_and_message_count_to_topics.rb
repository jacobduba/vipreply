class AddDoNotReplyAndMessageCountToTopics < ActiveRecord::Migration[8.0]
  def change
    add_column :topics, :do_not_reply, :boolean
    add_column :topics, :message_count, :integer
  end
end
