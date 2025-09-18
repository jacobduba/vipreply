class AddUniqueIndexToTopicsThreadId < ActiveRecord::Migration[8.0]
  def change
    add_index :topics, :thread_id, unique: true
  end
end
