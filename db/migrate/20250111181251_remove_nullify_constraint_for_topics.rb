class RemoveNullifyConstraintForTopics < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :topics, :templates
    add_foreign_key :topics, :templates  # standard foreign key without nullify
    # This is so we can use callbacks with nullify by using ActiveRecord callbacks
  end
end
