namespace :embeddings do
  desc "Migrate data from vector column to embedding_new column"
  task next_backfill: :environment do
    puts "Starting backfill..."

    MessageEmbedding.where(embedding_next: nil).includes(:message).find_each do |message_embedding|
      t0 = Time.now.to_f
      message_embedding.populate_next
      message_embedding.save!
      t1 = Time.now.to_f
      puts "Processed #{message_embedding.id} in #{(t1 - t0).round(3)} seconds"
    end

    puts "Backfill completed!"
  end

  task sandbox_populate: :environment do
    if Rails.env.production?
      raise <<~ERROR
        WARNING: Sandbox populate should not be run in production!
        Sandbox embeddings are only for development.
        Use 'rake embeddings:backfill_next' to safely backfill next.
      ERROR
    end

    puts "Starting population..."

    MessageEmbedding.includes(:message).find_each do |message_embedding|
      t0 = Time.now.to_f
      message_embedding.populate_sandbox
      message_embedding.save!
      t1 = Time.now.to_f
      puts "Prcoesssed #{message_embedding.id} in #{(t1 - t0).round(3)} seconds"
    end

    puts "Populate completed!"
  end
end
