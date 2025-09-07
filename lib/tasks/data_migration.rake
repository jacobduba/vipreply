namespace :data_migration do
  desc "Migrate data from vector column to embedding_new column"
  task migrate_embeddings: :environment do
    puts "Starting data migration..."

    MessageEmbedding.where(new_embedding: nil).includes(:message).find_each do |message_embedding|
      t0 = Time.now.to_f

      new_embedding = MessageEmbedding.create_new_embedding(message_embedding.message)
      message_embedding.update(new_embedding: new_embedding)

      t1 = Time.now.to_f
      puts "Processed #{message_embedding.id} in #{(t1 - t0).round(3)} seconds"
    end

    puts "Data migration completed!"
  end
end
