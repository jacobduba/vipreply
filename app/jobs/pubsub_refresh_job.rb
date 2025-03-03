class PubsubRefreshJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "Starting nightly Gmail watch refresh"
    start_time = Time.current

    # Update to use Inbox model
    Inbox.where(provider: "google_oauth2").find_each do |inbox|
      inbox.watch_for_changes
    rescue => e
      Rails.logger.error "Failed to refresh Gmail watch for inbox #{inbox.id}: #{e.message}"
    end

    Rails.logger.info "Completed Gmail watch refresh in #{Time.current - start_time} seconds"
  end
end
