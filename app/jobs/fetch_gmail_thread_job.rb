class FetchGmailThreadJob < ApplicationJob
  queue_as :default

  # Retry on rate limit errors with exponential backoff
  retry_on Google::Apis::RateLimitError, wait: :exponentially_longer, attempts: 5
  # Consider retrying other transient errors as needed
  # retry_on Google::Apis::ServerError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveJob::DeserializationError # Ignore if records are deleted

  def perform(inbox_id, thread_id, snippet)
    inbox = Inbox.find_by(id: inbox_id)
    unless inbox
      Rails.logger.warn "FetchGmailThreadJob: Inbox #{inbox_id} not found. Skipping thread #{thread_id}."
      return
    end

    Rails.logger.info "FetchGmailThreadJob: Starting fetch for thread #{thread_id} in inbox #{inbox_id}"

    account = inbox.account
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = account.google_credentials

    begin
      thread_response = gmail_service.get_user_thread("me", thread_id)

      # Process the fetched thread
      # Using the same caching logic as the original batch callback
      Topic.cache_from_gmail(thread_response, snippet, inbox)

      Rails.logger.info "FetchGmailThreadJob: Successfully processed thread #{thread_id} for inbox #{inbox.id}"
    rescue Google::Apis::RateLimitError => e
      # This exception will be caught by retry_on, but log it for visibility
      Rails.logger.warn "FetchGmailThreadJob: Rate limit error fetching thread #{thread_id} for inbox #{inbox.id}. Error: #{e.message}. Retrying..."
      raise e # Re-raise to trigger retry mechanism
    end
  end
end
