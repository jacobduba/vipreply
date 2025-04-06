class SetupInboxJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find(inbox_id)
    account = inbox.account

    case inbox.provider
    when "google_oauth2"
      setup_gmail_inbox(inbox, account)
    when "microsoft_office365"
      setup_outlook_inbox(inbox, account)
    else
      Rails.logger.error "Unknown provider: #{inbox.provider}"
    end
  end

  private

  def setup_gmail_inbox(inbox, account)
    # Initialize Gmail API client
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = inbox.credentials
    user_id = "me"

    begin
      # Fetch the user's profile to get the latest history_id
      profile = gmail_service.get_user_profile(user_id)
      inbox.update!(history_id: profile.history_id.to_i)

      # Fetch thread IDs with a single request
      # Using 90 days temporarily
      query = "newer_than:90d"
      threads_response = gmail_service.list_user_threads(user_id, q: query) 

      # Ensure threads_response and threads_response.threads are not nil before proceeding
      if threads_response&.threads
        thread_info = threads_response.threads.map do |thread|
          {id: thread.id, snippet: thread.snippet}
        end

        Rails.logger.info "Found #{thread_info.count} threads for inbox #{inbox.id}. Enqueuing individual fetch jobs."

        inbox.watch_for_changes

        thread_info.each do |thread|
          FetchGmailThreadJob.perform_later(inbox.id, thread[:id], thread[:snippet])
        end
        Rails.logger.info "Finished enqueuing fetch jobs for inbox #{inbox.id}."
      else
        Rails.logger.info "No threads found for inbox #{inbox.id} matching query '#{query}'."
        # Still set up the watch even if no threads are found initially
        inbox.watch_for_changes
      end

    rescue Google::Apis::Error => e
      Rails.logger.error "Error setting up Gmail inbox #{inbox.id}: #{e.message}"
      # Consider re-raising or specific error handling if needed
    end
  end

  def setup_outlook_inbox(inbox, account)
    Rails.logger.info "Setting up Outlook inbox for #{account.email}"

    begin
      # Create Faraday connection with proper authorization
      conn = Faraday.new(url: "https://graph.microsoft.com/v1.0") do |faraday|
        faraday.request :authorization, "Bearer", inbox.access_token
        faraday.request :json
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end

      three_weeks_ago = 3.weeks.ago.utc.iso8601
      inbox.update(last_sync_time: Time.current)

      # First, query for messages in the inbox with proper URL formatting
      inbox_response = conn.get("/v1.0/me/mailFolders/inbox/messages") do |req|
        req.params = {
          "$filter": "receivedDateTime ge #{three_weeks_ago}",
          "$orderby": "receivedDateTime desc",
          "$expand": "attachments"
        }
      end

      sent_response = conn.get("/v1.0/me/mailFolders/sentitems/messages") do |req|
        req.params = {
          "$filter": "sentDateTime ge #{three_weeks_ago}",
          "$orderby": "sentDateTime desc",
          "$expand": "attachments"
        }
      end

      puts("INBOX RESPONSE: #{inbox_response.body}")
      puts("SENT RESPONSE: #{sent_response.body}")

      messages = []
      messages += inbox_response.body["value"] if inbox_response.success?
      messages += sent_response.body["value"] if sent_response.success?

      if messages.empty?
        Rails.logger.info "No messages found in inbox or sent items."
      end

      conversations = messages.group_by { |msg| msg["conversationId"] }
      conversations.each do |conversation_id, conversation_messages|
        next if conversation_messages.empty?
        sorted_messages = conversation_messages.sort_by { |msg| msg["receivedDateTime"] }
        conversation = {"id" => conversation_id, "messages" => sorted_messages}
        Topic.cache_from_outlook(conversation, inbox)
      end
    rescue => e
      Rails.logger.error "Error setting up Outlook inbox: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
