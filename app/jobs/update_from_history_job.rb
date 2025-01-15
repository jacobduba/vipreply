require "google/apis/gmail_v1"

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

    if history_response.history.present?
      history_response.history.each do |history|
        history.messages_added&.each do |message_meta|
          next if message_meta.message.label_ids&.include?("DRAFT")

          thread_id = message_meta.message.thread_id

          # Fetch the entire thread from Gmail
          thread_response = gmail_service.get_user_thread(user_id, thread_id)

          # Recreate the thread and its messages
          Topic.cache_from_gmail(thread_response, thread_response.messages.last.snippet, inbox)
        end
      end
    else
      Rails.logger.info "No new history changes for inbox #{inbox.id}."
    end

    # Update the latest history_id
    if history_response.history_id
      inbox.update!(history_id: history_response.history_id.to_i)
    end
  end
end
