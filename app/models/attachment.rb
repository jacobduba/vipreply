class Attachment < ApplicationRecord
  belongs_to :message

  def self.cache_from_gmail(message, attachment_data)
    existing_attachment = msg.attachments.find_or_initialize_by(
      attachment_id: attachment[:attachment_id]
    )

    existing_attachment.assign_attributes(
      content_id: attachment[:content_id],
      filename: attachment[:filename],
      mime_type: attachment[:mime_type],
      size: attachment[:size]
    )

    if existing_attachment.changed?
      existing_attachment.save!
      Rails.logger.info "Saved attachment: #{existing_attachment.id}"
    else
      Rails.logger.info "No changes for attachment: #{existing_attachment.id}"
    end

    existing_attachment
  end
end
