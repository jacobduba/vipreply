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

    # Ensure the inbox provider is correct
    unless inbox.provider == "google_oauth2"
      Rails.logger.error "FetchGmailThreadJob: Inbox #{inbox_id} is not a Gmail inbox. Skipping thread #{thread_id}."
      return
    end

    Rails.logger.info "FetchGmailThreadJob: Starting fetch for thread #{thread_id} in inbox #{inbox_id}"

    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = inbox.credentials

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
    rescue Google::Apis::ClientError => e
      # Handle other client errors (e.g., 404 Not Found if thread deleted, 401/403 auth issues)
      Rails.logger.error "FetchGmailThreadJob: Client error fetching thread #{thread_id} for inbox #{inbox.id}. Error: #{e.status_code} - #{e.message}"
      # Depending on the error, you might not want to retry (e.g., 404)
    rescue => e
      # Catch unexpected errors
      Rails.logger.error "FetchGmailThreadJob: Unexpected error fetching thread #{thread_id} for inbox #{inbox.id}. Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Consider whether to retry unexpected errors or not
    end
  end
end