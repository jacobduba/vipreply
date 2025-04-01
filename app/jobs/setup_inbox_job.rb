class SetupInboxJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find(inbox_id)

    account = inbox.account

    # Initialize Gmail API client
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = account.google_credentials
    user_id = "me"

    # Fetch the user's profile to get the latest history_id
    profile = gmail_service.get_user_profile(user_id)
    inbox.update!(history_id: profile.history_id.to_i)

    # Fetch thread IDs with a single request
    query = "newer_than:21d"
    threads_response = gmail_service.list_user_threads(user_id, q: query)
    thread_info = threads_response.threads.map do |thread|
      {id: thread.id, snippet: thread.snippet}
    end

    account.refresh_gmail_watch

    gmail_service.batch do |gmail_service|
      thread_info.each do |thread|
        gmail_service.get_user_thread("me", thread[:id]) do |res, err|
          if err
            Rails.logger.error "Error fetching thread #{thread[:id]}: #{err.message}"
            Honeybadger.notify(err)
          else
            Topic.cache_from_gmail(res, thread[:snippet], inbox)
          end
        end
      end
    end
  end
end
