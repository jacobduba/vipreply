namespace :embeddings do
  desc "Migrate data from vector column to embedding_new column"
  task upgrade: :environment do
    puts "Starting upgrade..."

    MessageEmbedding.where(embedding_next: nil).includes(:message).find_each do |message_embedding|
      # pool.post do
      t0 = Time.now.to_f
      message_embedding.populate_next
      message_embedding.save!
      t1 = Time.now.to_f
      puts "Processed #{message_embedding.id} in #{(t1 - t0).round(3)} seconds"
      # rescue => e
      #   puts "Error processing #{message_embedding.id}: #{e.message}"
      # end
    end

    # pool.shutdown
    # pool.wait_for_termination

    puts "Upgrade completed!"
  end

  task reload: :environment do
    require "async"
    require "async/semaphore"
    require "async/queue"
    require "async/barrier"

    if Rails.env.production?
      raise <<~ERROR
        ERROR: Reload should not be used in production!
        Reload dangerously replaces embeddings in-place.
        Use 'rails embeddings:upgrade' in conjuction with migrations to safely backfill.
      ERROR
    end

    puts "Starting swap..."

    CONCURRENT_HTTP = ENV["CONCURRENT_HTTP"] || 40
    # CONCURRENT_DB = ENV["CONCURRENT_DB"] || 2

    # Producer consumer with apis and db. because only so many db connections AND apis are slower.
    # so lots of api calls a few db connections
    Async do
      queue = Async::LimitedQueue.new(50)
      Async do
        barrier = Async::Barrier.new
        semaphore = Async::Semaphore.new(CONCURRENT_HTTP, parent: barrier)

        MessageEmbedding.includes(:message).find_each do |message_embedding|
          semaphore.async do
            queue << {id: message_embedding.id, embedding: message_embedding.generate_embedding_sandbox}
          rescue => e
            puts "Error processing #{message_embedding.id}:"
            puts e.message
            puts e.backtrace
          end
        end

        barrier.wait
      ensure
        barrier&.stop
        queue.close
      end

      # CONCURRENT_DB.times do
      # Async do
      # ActiveRecord::Base.connection_pool.with_connection do
      while me = queue.dequeue
        MessageEmbedding.update(me[:id], embedding: me[:embedding])
        puts "Rereloaded #{me[:id]}"
      end
      # end
      # end
      # end
    end

    puts "Sandbox swap completed!"
  end
end
