namespace :data_migration do
  desc "Migrate data from vector column to embedding_new column"
  task migrate_embeddings: :environment do
    puts "Starting data migration..."

    MessageEmbedding.where(new_embedding: nil).includes(:message).find_each do |message_embedding|
      new_embedding = MessageEmbedding.create_new_embedding(message_embedding.message)
      message_embedding.update(new_embedding: new_embedding)
      puts "Processed #{message_embedding.id}"
    end

    puts "Data migration completed!"
  end
end
