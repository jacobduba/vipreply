class Attachment < ApplicationRecord
  belongs_to :message, dependent: :destroy

  enum :content_disposition, [:inline, :attachment]

  def self.cache_from_provider(message, attachment_data)
    if message.topic.inbox.provider == "google_oauth2"
      cache_from_gmail(message, attachment_data)
    else
      # For Outlook
      content_disposition = attachment_data[:content_disposition] || "attachment"
      content_disposition = content_disposition.to_sym if content_disposition.is_a?(String)

      create!(
        message: message,
        attachment_id: attachment_data[:attachment_id],
        content_id: attachment_data[:content_id],
        filename: attachment_data[:filename],
        mime_type: attachment_data[:mime_type],
        size: attachment_data[:size],
        content_disposition: content_disposition
      )
    end
  end

  def self.cache_from_gmail(message, attachment_data)
    # For Gmail attachments, determine content disposition
    content_disposition_value = attachment_data[:content_disposition]

    # Determine if inline or attachment
    content_disposition = if content_disposition_value == "inline"
      :inline
    else
      :attachment
    end

    # Create the attachment record
    create!(
      message: message,
      attachment_id: attachment_data[:attachment_id],
      content_id: attachment_data[:content_id],
      filename: attachment_data[:filename],
      mime_type: attachment_data[:mime_type],
      size: attachment_data[:size],
      content_disposition: content_disposition
    )
  end

  def self.cache_from_outlook(message, attachment_data)
    create!(
      message: message,
      attachment_id: attachment_data[:attachment_id],
      content_id: attachment_data[:content_id],
      filename: attachment_data[:filename] || "attachment.bin",
      mime_type: attachment_data[:mime_type] || "application/octet-stream",
      size: attachment_data[:size] || 0,
      content_disposition: attachment_data[:content_disposition].to_sym
    )
  end

  # Get url
  def url(host)
    "#{host}/attachments/#{id}"
  end
end
