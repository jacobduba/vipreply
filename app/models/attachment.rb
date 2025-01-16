class Attachment < ApplicationRecord
  belongs_to :message

  def self.cache_from_gmail(message, attachment_data)
    attachment = message.attachments.find_or_initialize_by(
      attachment_id: attachment_data[:attachment_id]
    )

    attachment.assign_attributes(
      content_id: attachment_data[:content_id],
      filename: attachment_data[:filename],
      mime_type: attachment_data[:mime_type],
      size: attachment_data[:size]
    )

    if attachment.changed?
      attachment.save!
      Rails.logger.info "Saved attachment: #{attachment.id}"
    else
      Rails.logger.info "No changes for attachment: #{attachment.id}"
    end
  end
end
