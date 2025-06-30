# frozen_string_literal: true

class SetupInboxJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find(inbox_id)

    account = inbox.account

    user_id = "me"

    account.with_gmail_service do |service|
      # Fetch the user's profile to get the latest history_id
      profile = service.get_user_profile(user_id)
      inbox.update!(history_id: profile.history_id.to_i)

      # Fetch thread IDs with a single request
      query = "newer_than:60d"
      threads_response = service.list_user_threads(user_id, q: query)

      account.refresh_gmail_watch

      unless threads_response&.threads
        Rails.logger.info "No threads found for inbox #{inbox.id} matching query '#{query}'."
        next
      end

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
    end
  end
end
