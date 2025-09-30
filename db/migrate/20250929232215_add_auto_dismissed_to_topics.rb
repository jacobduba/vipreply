class AddAutoDismissedToTopics < ActiveRecord::Migration[8.0]
  def change
    add_column :topics, :auto_dismissed, :boolean
  end
end
