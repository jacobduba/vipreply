class RemoveInputColumnsFromTemplates < ActiveRecord::Migration[8.0]
  def change
    remove_column :templates, :input, :text
    remove_column :templates, :input_embedding, :vector
  end
end
