# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def self.cache_from_provider(message, attachment_data)
    if message.topic.inbox.provider == "google_oauth2"
      cache_from_gmail(message, attachment_data)
    else
      create!(
        message: message,
        attachment_id: attachment_data[:attachment_id],
        content_id: attachment_data[:content_id],
        filename: attachment_data[:filename],
        mime_type: attachment_data[:mime_type],
        size: attachment_data[:size],
        content_disposition: attachment_data[:content_disposition]
      )
    end
  end
end
