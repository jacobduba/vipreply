class ContractEmbeddings1 < ActiveRecord::Migration[8.0]
  def change
    remove_column :message_embeddings, :embedding
    rename_column :message_embeddings, :embedding_next, :embedding
  end
end
