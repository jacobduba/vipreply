class SwapEmbeddings1 < ActiveRecord::Migration[8.0]
  def change
    remove_column :message_embeddings, :embedding
    rename_column :message_embeddings, :new_embedding, :embedding
  end
end
