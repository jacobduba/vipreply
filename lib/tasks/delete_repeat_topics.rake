namespace :delete_repeat_topics do
  desc "Backfills embedding_next column for upgrades"
  task go: :environment do
    Topic.select(:thread_id).group(:thread_id).each do |group|
      topics = Topic.where(thread_id: group.thread_id).order(:id)
      duplicates = topics.offset(1)

      duplicates.each do |dup|
        dup.destroy!
      end
    end
  end
end
