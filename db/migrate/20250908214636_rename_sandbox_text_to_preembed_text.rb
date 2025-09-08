class RenameSandboxTextToPreembedText < ActiveRecord::Migration[8.0]
  def change
    rename_column :message_embeddings, :sandbox_text, :preembed_text
  end
end
