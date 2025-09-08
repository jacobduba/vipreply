class AddEmbeddingNextToMessageEmbeddings < ActiveRecord::Migration[8.0]
  def change
    add_column :message_embeddings, :embedding_next, :vector, limit: 1024
  end
end
