class RemoveExamplesAndModels < ActiveRecord::Migration[8.0]
  def change
    drop_table :examples
    drop_table :models
  end
end
