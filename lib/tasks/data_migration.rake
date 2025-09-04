namespace :data_migration do
  desc "Migrate data from vector column to embedding_new column"
  task migrate_embeddings: :environment do
    puts "Starting data migration..."

    MessageEmbedding.where(embedding_new: nil).find_each do |embedding|
      # Your data migration logic here
      # Example: embedding.update!(embedding_new: embedding.vector)

      embedding_new = MessageEmbedding.new_create_embedding(embedding.message)
      embedding.update(embedding_new: embedding_new)

      puts "Processed #{embedding.id}"
    end

    puts "Data migration completed!"
  end
end
