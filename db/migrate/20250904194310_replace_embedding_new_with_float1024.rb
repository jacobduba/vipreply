class ReplaceEmbeddingNewWithFloat1024 < ActiveRecord::Migration[8.0]
  def change
    remove_column :message_embeddings, :embedding_new, :bit
    add_column :message_embeddings, :embedding_new, :vector, limit: 1024
  end
end
