class AddNullifyConstraintToTopicsTemplate < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :topics, :templates, if_exists: true
    add_foreign_key :topics, :templates, on_delete: :nullify
  end
end
