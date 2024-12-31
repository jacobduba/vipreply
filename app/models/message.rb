class Message < ApplicationRecord
  belongs_to :topic
  has_many :attachments, dependent: :destroy

  def replace_cids_with_urls
    return html unless html

    updated_html = html.dup

    attachments.each do |attachment|
      next unless attachment.content_id

      attachment_url = "/attachments/#{attachment.id}"

      updated_html.gsub!(attachment.content_id, attachment_url)
    end

    updated_html
  end
end
