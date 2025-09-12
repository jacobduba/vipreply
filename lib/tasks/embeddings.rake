namespace :embeddings do
  desc "Backfills embedding_next column for upgrades"
  task upgrade: :environment do
    require "async"
    require "async/semaphore"
    require "async/queue"
    require "async/barrier"
    puts "Starting upgrade..."

    concurrent_http = (ENV["CONCURRENT_HTTP"] || 40).to_i

    # Producer consumer with apis and db. because only so many db connections AND apis are slower.
    # so lots of api calls a few db connections
    Async do
      queue = Async::LimitedQueue.new(10)
      Async do
        barrier = Async::Barrier.new
        semaphore = Async::Semaphore.new(concurrent_http, parent: barrier)

        MessageEmbedding.where(embedding_next: nil).includes(:message).find_each do |message_embedding|
          semaphore.async do
            queue << {id: message_embedding.id, embedding_next: message_embedding.generate_embedding_next}
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

      # Only one AR connection allowed per thread
      while (me = queue.dequeue)
        MessageEmbedding.update(me[:id], embedding_next: me[:embedding_next])
        puts "Rereloaded #{me[:id]}"
      end
    end

    # pool.shutdown
    # pool.wait_for_termination

    puts "Upgrade completed!"
  end

  desc "In place swaps embeddings column with the generate_embedding_sandbox. Made for development."
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

    concurrent_http = (ENV["CONCURRENT_HTTP"] || 40).to_i

    # Producer consumer with apis and db. because only so many db connections AND apis are slower.
    # so lots of api calls a few db connections
    Async do
      queue = Async::LimitedQueue.new(10)
      Async do
        barrier = Async::Barrier.new
        semaphore = Async::Semaphore.new(concurrent_http, parent: barrier)

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

      # Only one AR connection allowed per thread
      while (me = queue.dequeue)
        MessageEmbedding.update(me[:id], embedding: me[:embedding])
        puts "Rereloaded #{me[:id]}"
      end
    end

    puts "Sandbox swap completed!"
  end
end
