class PubsubRefreshJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "Starting nightly Gmail watch refresh"
    start_time = Time.current

    Account.refresh_all_gmail_watches

    Rails.logger.info "Completed Gmail watch refresh in #{Time.current - start_time} seconds"
  end
end
