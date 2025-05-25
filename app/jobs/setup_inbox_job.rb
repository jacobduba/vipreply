class SetupInboxJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find(inbox_id)

    account = inbox.account

    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = account.google_credentials
    user_id = "me"

    begin
      # Fetch the user's profile to get the latest history_id
      profile = gmail_service.get_user_profile(user_id)
      inbox.update!(history_id: profile.history_id.to_i)

      # Fetch thread IDs with a single request
      # Using 180 days temporarily
      query = "newer_than:180d"
      threads_response = gmail_service.list_user_threads(user_id, q: query)

      # Ensure threads_response and threads_response.threads are not nil before proceeding
      if threads_response&.threads
        thread_info = threads_response.threads.map do |thread|
          {id: thread.id, snippet: thread.snippet}
        end

        Rails.logger.info "Found #{thread_info.count} threads for inbox #{inbox.id}. Enqueuing individual fetch jobs."

        account.refresh_gmail_watch

        thread_info.each do |thread|
          FetchGmailThreadJob.perform_later(inbox.id, thread[:id], thread[:snippet])
        end
        Rails.logger.info "Finished enqueuing fetch jobs for inbox #{inbox.id}."
      else
        Rails.logger.info "No threads found for inbox #{inbox.id} matching query '#{query}'."
        # Still set up the watch even if no threads are found initially
        account.refresh_gmail_watch
      end
    rescue Google::Apis::Error => e
      Rails.logger.error "Error setting up Gmail inbox #{inbox.id}: #{e.message}"
      # Consider re-raising or specific error handling if needed
    end
  end
end
