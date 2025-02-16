class ModifyExamplesForEmbedding < ActiveRecord::Migration[8.0]
  def change
    remove_column :examples, :message_id, :bigint
    remove_column :examples, :message_embedding, :vector
    add_reference :examples, :embedding, foreign_key: true, type: :bigint
  end
end
