class UpdateFromHistoryJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find(inbox_id)
    account = inbox.account
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = account.google_credentials

    user_id = "me"
    history_id = inbox.history_id

    Rails.logger.info "Updating inbox from history_id: #{history_id} for inbox #{inbox.id}"

    # Fetch history since the last `history_id`
    history_response = gmail_service.list_user_histories(
      user_id,
      start_history_id: history_id,
      history_types: ["messageAdded", "messageDeleted"]
    )
    # rescue Google::Apis::ClientError => e
    #   Rails.logger.error "Failed to update inbox from history: #{e.message}"
    #   return

    # Log history count instead of the entire response
    if history_response.history
      Rails.logger.info "Received #{history_response.history.count} history changes for inbox #{inbox.id}."
    else
      Rails.logger.info "No new history changes for inbox #{inbox.id}."
      return
    end

    history_response.history.each do |history|
      history_item_id = history.id.to_i

      history.messages_added&.each do |message_meta|
        next if message_meta.message.label_ids&.include?("DRAFT")

        thread_id = message_meta.message.thread_id

        begin
          thread_response = gmail_service.get_user_thread(user_id, thread_id)
          Topic.cache_from_gmail(thread_response, thread_response.messages.last.snippet, inbox)
        rescue Google::Apis::ClientError => e
          if e.status_code == 404
            Rails.logger.error "Thread not found (404): #{thread_id}. Skipping."
          else
            raise e
          end
        end

        inbox.update!(history_id: history_item_id)
      end
    end
  end
end
