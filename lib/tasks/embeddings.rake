namespace :embeddings do
  desc "Backfills embedding_next column for upgrades"
  task upgrade: :environment do
    require "async"
    require "async/semaphore"

    concurrent_req = (ENV["CONCURRENT_REQ"] || 50).to_i

    puts "Starting upgrade..."

    # todo? make it rewrite ALL embedding next? not just whats null
    MessageEmbedding.where(embedding_next: nil).includes(:message).find_in_batches do |batch|
      message_embeddings = Sync do
        semaphore = Async::Semaphore.new(concurrent_req)

        batch.map { |message_embedding|
          semaphore.async do
            ret = {
              id: message_embedding.id,
              embedding_next: message_embedding.generate_embedding_next
            }
            puts "Fetched embedding #{message_embedding.id}"
            ret
          end
        }.map(&:wait)
      end

      ids = message_embeddings.map { |me| me[:id] }
      embedding_nexts = message_embeddings.map { |me| {embedding_next: me[:embedding_next]} }
      MessageEmbedding.update!(ids, embedding_nexts)

      puts "==========\nSaved #{embedding_nexts.size} embeddings\n=========="
    end

    puts "Upgrade completed!"
  end

  desc "In place swaps embeddings column with the generate_embedding_sandbox. Made for development."
  task reload: :environment do
    require "async"
    require "async/semaphore"

    if Rails.env.production?
      raise <<~ERROR
        ERROR: Reload should not be used in production!
        Reload dangerously replaces embeddings in-place.
        Use 'rails embeddings:upgrade' in conjuction with migrations to safely backfill.
      ERROR
    end

    concurrent_req = (ENV["CONCURRENT_REQ"] || 50).to_i

    puts "Starting swap..."

    MessageEmbedding.includes(:message).find_in_batches do |batch|
      message_embeddings = Sync do
        semaphore = Async::Semaphore.new(concurrent_req)

        batch.map { |message_embedding|
          semaphore.async do
            {
              id: message_embedding.id,
              embedding: message_embedding.generate_embedding_sandbox
            }
          end
        }.map(&:wait)
      end

      ids = message_embeddings.map { |me| me[:id] }
      embeddings = message_embeddings.map { |me| {embedding: me[:embedding]} }
      MessageEmbedding.update!(ids, embeddings)

      puts "Processed #{embeddings.size} embeddings"
    end
  end
end
