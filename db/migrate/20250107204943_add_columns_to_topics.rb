class AddColumnsToTopics < ActiveRecord::Migration[8.0]
  def change
    add_reference :topics, :template, null: true, foreign_key: true
    add_column :topics, :generated_email, :string
  end
end
