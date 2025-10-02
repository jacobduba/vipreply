class AddIsSelectingToTopics < ActiveRecord::Migration[8.0]
  def change
    add_column :topics, :is_selecting_templates, :boolean, default: true, null: false
  end
end
