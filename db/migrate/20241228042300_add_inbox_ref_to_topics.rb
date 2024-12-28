class AddInboxRefToTopics < ActiveRecord::Migration[8.0]
  def change
    add_reference :topics, :inbox, null: false, foreign_key: true
  end
end
