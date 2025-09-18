namespace :delete_repeat_topics do
  desc "Deletes duplicate topics, keeping the earliest one for each thread_id."
  task go: :environment do
    puts "--- Starting the duplicate topic deletion process ---"

    unique_thread_ids = Topic.distinct.pluck(:thread_id)
    puts "Found #{unique_thread_ids.count} unique thread_ids to process."

    unique_thread_ids.each do |thread_id|
      puts "\nProcessing thread_id: #{thread_id}..."

      topics = Topic.where(thread_id: thread_id).order(:id)
      total_topics = topics.count

      if total_topics <= 1
        puts "  -> Found only one topic. No duplicates to delete. Skipping."
        next
      end

      puts "  -> Found #{total_topics} total topics for this thread."

      original_topic = topics.first
      duplicates = topics.offset(1)

      puts "  -> Keeping original Topic with ID: #{original_topic.id}."
      puts "  -> Preparing to delete #{duplicates.count} duplicate(s)."

      duplicates.each do |dup|
        puts "    -> Deleting duplicate Topic with ID: #{dup.id}..."
        dup.destroy!
        puts "    -> Successfully deleted."
      end
    end

    puts "\n--- Finished the duplicate topic deletion process ---"
  end
end
