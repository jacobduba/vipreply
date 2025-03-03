class DropExampleRelatedTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :examples, if_exists: true
    drop_table :example_messages, if_exists: true
    drop_table :embeddings, if_exists: true
  end
end
