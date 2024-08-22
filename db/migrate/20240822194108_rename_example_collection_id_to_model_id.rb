class RenameExampleCollectionIdToModelId < ActiveRecord::Migration[7.1]
  def change
    rename_column :examples, :collection_id, :model_id
  end
end
