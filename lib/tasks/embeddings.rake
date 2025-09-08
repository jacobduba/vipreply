namespace :embeddings do
  desc "Migrate data from vector column to embedding_new column"
  task upgrade: :environment do
    puts "Starting upgrade..."

    pool = Concurrent::FixedThreadPool.new(30)

    MessageEmbedding.where(embedding_next: nil).includes(:message).find_each do |message_embedding|
      pool.post do
        t0 = Time.now.to_f
        message_embedding.populate_next
        message_embedding.save!
        t1 = Time.now.to_f
        puts "Processed #{message_embedding.id} in #{(t1 - t0).round(3)} seconds"
      rescue => e
        puts "Error processing #{message_embedding.id}: #{e.message}"
      end
    end

    pool.shutdown
    pool.wait_for_termination

    puts "Upgrade completed!"
  end

  task swap: :environment do
    require "concurrent"

    if Rails.env.production?
      raise <<~ERROR
        ERROR: Swap cannot be run in production!
        Use 'rails embeddings:upgrade' in conjuction with migrations to safely backfill.
      ERROR
    end

    puts "Starting swap..."

    pool = Concurrent::FixedThreadPool.new(30)

    MessageEmbedding.includes(:message).find_each do |message_embedding|
      pool.post do
        t0 = Time.now.to_f
        message_embedding.populate_sandbox
        message_embedding.save!
        t1 = Time.now.to_f
        puts "Processed #{message_embedding.id} in #{(t1 - t0).round(3)} seconds"
      rescue => e
        puts "Error processing #{message_embedding.id}: #{e.message}"
      end
    end

    pool.shutdown
    pool.wait_for_termination

    puts "Swap completed!"
  end
end
