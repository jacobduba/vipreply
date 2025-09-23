# frozen_string_literal: true

class Attachment < ApplicationRecord
  belongs_to :message

  # An inline attachment appears directly embedded within the message content
  # Attachment disposition means the file should be downloaded rather than displayed
  enum :content_disposition, [ :inline, :attachment ]

  def self.cache_from_gmail(message, gmail_api_attachment)
    # content id is static, but apparently attachment id isn't. huh
    attachment = message.attachments.find_or_initialize_by(content_id: gmail_api_attachment[:content_id])

    attachment.assign_attributes(
      message: message,
      attachment_id: gmail_api_attachment[:attachment_id],
      content_id: gmail_api_attachment[:content_id],
      filename: gmail_api_attachment[:filename],
      mime_type: gmail_api_attachment[:mime_type],
      size: gmail_api_attachment[:size],
      content_disposition: gmail_api_attachment[:content_disposition]
    )

    attachment
  end
end
