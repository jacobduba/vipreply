class CreateMessageEmbeddings < ActiveRecord::Migration[8.0]
  def change
    create_table :message_embeddings do |t|
      t.vector :vector, limit: 2048
      t.references :message, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end

    # Create join table for MessageEmbedding and Template
    create_table :message_embeddings_templates, id: false do |t|
      t.belongs_to :message_embedding, null: false
      t.belongs_to :template, null: false

      t.index [ :message_embedding_id, :template_id ], unique: true, name: "index_message_embeddings_templates_unique"
    end

    # Remove vector column from messages
    remove_column :messages, :vector, :vector

    # Drop the old join table
    drop_table :messages_templates
  end
end
