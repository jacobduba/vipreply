namespace :data_migration do
  desc "Migrate data from vector column to embedding_new column"
  task migrate_embeddings: :environment do
    puts "Starting data migration..."

    MessageEmbedding.where(embedding_new: nil).includes(:message).find_in_batches(batch_size: 128) do |message_embeddings|
      messages = message_embeddings.map(&:message)

      new_embeddings = MessageEmbedding.new_create_embeddings(messages)

      message_embeddings.zip(new_embeddings).each do |message_embedding, new_embedding|
        message_embedding.update!(embedding_new: new_embedding)
        puts "Processed #{message_embedding.id}"
      end
    end

    puts "Data migration completed!"
  end
end
