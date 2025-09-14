class AddWillAutoSendToTopics < ActiveRecord::Migration[8.0]
  def change
    add_column :topics, :will_autosend, :boolean, default: false
  end
end
