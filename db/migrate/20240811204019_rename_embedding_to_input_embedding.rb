class RenameEmbeddingToInputEmbedding < ActiveRecord::Migration[7.1]
  def change
    rename_column :examples, :embedding, :input_embedding
  end
end
