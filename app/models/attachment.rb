class Attachment < ApplicationRecord
  belongs_to :message, dependent: :delete

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

    Rails.logger.info "Saved attachment: #{attachment.id}"
  end

  # Get url
  def url(host)
    "#{host}/attachments/#{id}"
  end
end
