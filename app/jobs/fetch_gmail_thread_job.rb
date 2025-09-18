# frozen_string_literal: true

class FetchGmailThreadJob < ApplicationJob
  queue_as :default

  # Retry on rate limit errors with exponential backoff
  retry_on Google::Apis::RateLimitError, wait: :exponentially_longer, attempts: 5
  # Consider retrying other transient errors as needed
  # retry_on Google::Apis::ServerError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveJob::DeserializationError # Ignore if records are deleted

  def perform(inbox_id, thread_id, decrement_import_jobs_remaining: false)
    inbox = Inbox.find_by(id: inbox_id)
    unless inbox
      Rails.logger.warn "FetchGmailThreadJob: Inbox #{inbox_id} not found. Skipping thread #{thread_id}."
      return
    end

    Rails.logger.info "FetchGmailThreadJob: Starting fetch for thread #{thread_id} in inbox #{inbox_id}"

    account = inbox.account

    begin
      account.with_gmail_service do |service|
        thread_response = service.get_user_thread("me", thread_id)

        # Process the fetched thread
        # Using the same caching logic as the original batch callback
        Topic.cache_from_gmail(inbox, thread_response)

        Rails.logger.info "FetchGmailThreadJob: Successfully processed thread #{thread_id} for inbox #{inbox.id}"
      end
    ensure
      inbox.decrement!(:initial_import_jobs_remaining) if decrement_import_jobs_remaining
    end
  end
end
