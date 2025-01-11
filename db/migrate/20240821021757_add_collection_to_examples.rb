# frozen_string_literal: true

class AddCollectionToExamples < ActiveRecord::Migration[7.1]
  def change
    add_reference :examples, :collection, null: true, foreign_key: true
    change_column_null :examples, :collection_id, false
  end
end
