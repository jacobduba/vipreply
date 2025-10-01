class RemoveAutoDismissedFromTopics < ActiveRecord::Migration[8.0]
  def change
    remove_column :topics, :auto_dismissed, :boolean
  end
end
