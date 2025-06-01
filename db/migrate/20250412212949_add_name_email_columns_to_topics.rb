class AddNameEmailColumnsToTopics < ActiveRecord::Migration[8.0]
  def change
    rename_column :topics, :from, :from_email
    rename_column :topics, :to, :to_email
    add_column :topics, :from_name, :string
    add_column :topics, :to_name, :string
  end
end
