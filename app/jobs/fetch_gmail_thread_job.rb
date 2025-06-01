class FetchGmailThreadJob < ApplicationJob
  queue_as :default

  # Retry on rate limit errors with exponential backoff
  retry_on Google::Apis::RateLimitError, wait: :exponentially_longer, attempts: 5

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
      Topic.cache_from_gmail(thread_response, snippet, inbox) 
      Rails.logger.info "FetchGmailThreadJob: Successfully processed thread #{thread_id} for inbox #{inbox.id}"
    rescue Google::Apis::ClientError => e
      if e.status_code == 404
        Rails.logger.error "Thread not found (404): #{thread_id}. Skipping."
      else
        raise e
      end
    end
  end
end