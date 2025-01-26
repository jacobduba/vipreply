class RenameMessagePlaintextEmbeddingInExamples < ActiveRecord::Migration[8.0]
  def change
    rename_column :examples, :message_plaintext_embedding, :message_embedding
  end
end
