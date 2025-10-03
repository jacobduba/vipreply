class RemoveIsSelectingFromTopics < ActiveRecord::Migration[8.0]
  def change
    remove_column :topics, :is_selecting_cards, :boolean
  end
end
