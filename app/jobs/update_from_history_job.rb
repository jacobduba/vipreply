# app/jobs/update_from_history_job.rb
class UpdateFromHistoryJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find(inbox_id)

    case inbox.provider
    when "google_oauth2"
      update_gmail_inbox(inbox)
    when "microsoft_office365"
      update_outlook_inbox(inbox)
    else
      Rails.logger.error "Unknown provider: #{inbox.provider}"
    end
  end

  private

  def update_gmail_inbox(inbox)
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = inbox.credentials

    user_id = "me"
    history_id = inbox.history_id

    Rails.logger.info "Updating Gmail inbox from history_id: #{history_id} for inbox #{inbox.id}"

    begin
      # Fetch history since the last `history_id`
      history_response = gmail_service.list_user_histories(
        user_id,
        start_history_id: history_id,
        history_types: ["messageAdded"]
      )
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Failed to update inbox from history: #{e.message}"
      return
    end

    Rails.logger.info "History response: #{history_response.pretty_inspect}"

    unless history_response.history
      Rails.logger.info "No new history changes for inbox #{inbox.id}."
      return
    end

    history_response.history.each do |history|
      history_item_id = history.id.to_i

      history.messages_added&.each do |message_meta|
        # Skip drafts
        next if message_meta.message.label_ids&.include?("DRAFT")

        thread_id = message_meta.message.thread_id

        # Fetch the entire thread from Gmail
        thread_response = gmail_service.get_user_thread(user_id, thread_id)

        # Recreate the thread and its messages
        Topic.cache_from_gmail(thread_response, thread_response.messages.last.snippet, inbox)

        # Update history_id after each successful message processing
        inbox.update!(history_id: history_item_id)
      rescue => e
        Rails.logger.error "Failed to process message in thread #{thread_id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
      end
    end
  end

  def update_outlook_inbox(inbox)
    # Use last_sync_time if available, otherwise default to 2 days ago
    since_date = inbox.last_sync_time || 2.days.ago
    since_date_iso = since_date.utc.iso8601

    conn = Faraday.new(url: "https://graph.microsoft.com/v1.0") do |faraday|
      faraday.request :authorization, "Bearer", inbox.access_token
      faraday.request :json
      faraday.response :json
      faraday.adapter Faraday.default_adapter
    end

    # Query for messages in the Inbox based on receivedDateTime
    inbox_response = conn.get("/v1.0/me/mailFolders/inbox/messages") do |req|
      req.params = {
        "$filter": "receivedDateTime ge #{since_date_iso}",
        "$orderby": "receivedDateTime desc"
      }
    end

    # Query for messages in the Sent Items based on sentDateTime
    sent_response = conn.get("/v1.0/me/mailFolders/sentitems/messages") do |req|
      req.params = {
        "$filter": "sentDateTime ge #{since_date_iso}",
        "$orderby": "sentDateTime desc"
      }
    end

    messages = []
    messages += inbox_response.body["value"] if inbox_response.success?
    messages += sent_response.body["value"] if sent_response.success?

    if messages.empty?
      Rails.logger.error "Error fetching Outlook messages: #{inbox_response.body}" unless inbox_response.success?
      Rails.logger.error "Error fetching Outlook sent items: #{sent_response.body}" unless sent_response.success?
      return
    end

    # Update last_sync_time to now
    inbox.update(last_sync_time: Time.current)

    # Group messages by conversationId to reconstruct the threads
    conversations = messages.group_by { |msg| msg["conversationId"] }
    conversations.each do |_, conversation_messages|
      # Sort messages by their receivedDateTime (assuming all messages have one)
      sorted_messages = conversation_messages.sort_by { |msg| msg["receivedDateTime"] }
      conversation = {
        "id" => sorted_messages.first["conversationId"],
        "messages" => sorted_messages
      }
      Topic.cache_from_outlook(conversation, inbox)
    end
  end
end
