class RemoveAllTakenCareOfFromTopics < ActiveRecord::Migration[8.0]
  def change
    rename_column :topics, :all_taken_care_of, :awaiting_customer
  end
end
