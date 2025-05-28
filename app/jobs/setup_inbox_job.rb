class SetupInboxJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find(inbox_id)

    account = inbox.account

    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = account.google_credentials
    user_id = "me"

    # Fetch the user's profile to get the latest history_id
    profile = gmail_service.get_user_profile(user_id)
    inbox.update!(history_id: profile.history_id.to_i)

    # Fetch thread IDs with a single request
    query = "newer_than:60d"
    threads_response = gmail_service.list_user_threads(user_id, q: query)

    account.refresh_gmail_watch

    # Ensure threads_response and threads_response.threads are not nil before proceeding
    if threads_response&.threads
      # If import jobs remaining > 0, then we show a banner
      inbox.update!(initial_import_jobs_remaining: threads_response.threads.count)

      thread_info = threads_response.threads.map do |thread|
        {id: thread.id, snippet: thread.snippet}
      end

      Rails.logger.info "Found #{thread_info.count} threads for inbox #{inbox.id}. Enqueuing individual fetch jobs."

      thread_info.each do |thread|
        FetchGmailThreadJob.perform_later(inbox.id, thread[:id], thread[:snippet])
      end
      Rails.logger.info "Finished enqueuing fetch jobs for inbox #{inbox.id}."
    else
      Rails.logger.info "No threads found for inbox #{inbox.id} matching query '#{query}'."
      account.refresh_gmail_watch
    end
  end
end
