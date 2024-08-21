class AddCollectionToExamples < ActiveRecord::Migration[7.1]
  def change
    add_reference :examples, :collection, null: true, foreign_key: true 
    
    collection = Collection.create name: "Midway Park Saver"
    Example.update_all collection_id: collection.id

    change_column_null :examples, :collection_id, false
  end
end
