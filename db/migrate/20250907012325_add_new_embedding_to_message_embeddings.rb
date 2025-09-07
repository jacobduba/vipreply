class AddNewEmbeddingToMessageEmbeddings < ActiveRecord::Migration[8.0]
  def change
    add_column :message_embeddings, :new_embedding, :vector, limit: 1024
  end
end
