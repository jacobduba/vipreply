# frozen_string_literal: true

class UpdateFromHistoryJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find(inbox_id)
    account = inbox.account

    Rails.error.set_context(
      user_id: account.id,
      user_email: account.email
    )

    user_id = "me"
    history_id = inbox.history_id

    Rails.logger.info "Updating Gmail inbox from history_id: #{history_id} for inbox #{inbox.id}"

    account.with_gmail_service do |service|
      # Fetch history since the last `history_id`
      history_response = service.list_user_histories(
        user_id,
        start_history_id: history_id,
        history_types: ["messageAdded"]
      )

      unless history_response.history
        Rails.logger.info "No new history changes for inbox #{inbox.id}."
        next
      end

      history_response.history.each do |history|
        history_item_id = history.id.to_i

        history.messages_added&.each do |message_meta|
          # Skip drafts
          next if message_meta.message.label_ids&.include?("DRAFT")

          thread_id = message_meta.message.thread_id

          # Fetch the entire thread from Gmail
          thread_response = service.get_user_thread(user_id, thread_id)

          # Recreate the thread and its messages
          Topic.cache_from_gmail(thread_response, inbox)

          # Update history_id after each successful message processing
          inbox.update!(history_id: history_item_id)
        end
      end
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Failed to update inbox from history: #{e.message}"
      nil
    end
  rescue Account::NoGmailPermissionsError => e
    Rails.logger.error "No Gmail permissions for account #{account.email}: #{e.message}"
    nil
  end
end
