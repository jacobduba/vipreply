namespace :data_migration do
  desc "Migrate data from vector column to embedding_new column"
  task migrate_embeddings: :environment do
    puts "Starting data migration..."

    MessageEmbedding.find_each do |embedding|
      # Your data migration logic here
      # Example: embedding.update!(embedding_new: embedding.vector)

      puts "Processing #{embedding.id}"
    end

    puts "Data migration completed!"
  end
end
