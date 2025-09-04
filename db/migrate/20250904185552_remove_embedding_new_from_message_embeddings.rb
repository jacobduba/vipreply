class RemoveEmbeddingNewFromMessageEmbeddings < ActiveRecord::Migration[8.0]
  def change
    remove_column :message_embeddings, :embedding_new, :vector
    add_column :message_embeddings, :embedding_new, :bit, limit: 2048
  end
end
