# frozen_string_literal: true

class Attachment < ApplicationRecord
  belongs_to :message

  # An inline attachment appears directly embedded within the message content
  # Attachment disposition means the file should be downloaded rather than displayed
  enum :content_disposition, [:inline, :attachment]

  def self.cache_from_gmail(message, attachment_data)
    # Attachments are deleted and recreated because gmail doesn't have static IDs for them
    # https://serverfault.com/questions/398962/does-the-presence-of-a-content-id-header-in-an-email-mime-mean-that-the-attachm
    attachment = create!(
      message: message,
      attachment_id: attachment_data[:attachment_id],
      content_id: attachment_data[:content_id],
      filename: attachment_data[:filename],
      mime_type: attachment_data[:mime_type],
      size: attachment_data[:size],
      content_disposition: attachment_data[:content_disposition]
    )

    # I added this logging for honeybadger to debug phantom missing attachments
    Rails.logger.info(
      event_type: "attachment_created",
      attachment: attachment_data
    )
  end

  # Get url
  def url(host)
    "#{host}/attachments/#{id}"
  end
end
