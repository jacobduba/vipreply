class RemoveTemplateIdFromTopics < ActiveRecord::Migration[8.0]
  def change
    remove_reference :topics, :template, foreign_key: true
  end
end
