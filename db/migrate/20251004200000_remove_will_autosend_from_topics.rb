class RemoveWillAutosendFromTopics < ActiveRecord::Migration[7.1]
  def change
    remove_column :topics, :will_autosend, :boolean
  end
end
