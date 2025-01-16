class AddHistoryIdToInboxes < ActiveRecord::Migration[8.0]
  def change
    add_column :inboxes, :history_id, :bigint
  end
end
