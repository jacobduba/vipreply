class AddIsSpamToTopics < ActiveRecord::Migration[8.0]
  def change
    add_column :topics, :is_spam, :boolean, default: false
  end
end
