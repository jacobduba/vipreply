# frozen_string_literal: true

class RestoreGmailPubsubJob < ApplicationJob
  queue_as :default

  def perform(account_id)
    account = Account.find(account_id)
    account.refresh_gmail_watch
  end
end
