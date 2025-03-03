# frozen_string_literal: true

class AttachmentsController < ApplicationController
  def show
    # Find the attachment by ID or return a 404 error page
    attachment = Attachment.find_by(id: params[:id])

    unless attachment
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
      return
    end

    # Handle attachment download based on provider
    if attachment.message.topic.inbox.provider == "google_oauth2"
      download_gmail_attachment(attachment)
    else
      download_outlook_attachment(attachment)
    end
  end

  private

  def initialize_gmail_service
    @gmail_service = Google::Apis::GmailV1::GmailService.new
    @gmail_service.authorization = @account.google_credentials
  end

  def download_gmail_attachment(attachment)
    initialize_gmail_service

    user_id = "me"
    message_id = attachment.message.message_id
    attachment_id = attachment.attachment_id

    response = @gmail_service.get_user_message_attachment(user_id, message_id, attachment_id)

    attachment_data = response.data
    # Want to render in browser always, at least for now
    disposition_type = "inline"

    # Send the file to the browser
    send_data attachment_data,
      filename: attachment.filename,
      type: attachment.mime_type,
      disposition: disposition_type
  end

  def download_outlook_attachment(attachment)
    # Create Microsoft Graph API connection
    conn = Faraday.new(url: "https://graph.microsoft.com") do |faraday|
      faraday.request :authorization, "Bearer", @inbox.access_token
      faraday.adapter Faraday.default_adapter
    end

    # Fetch the attachment content - notice the different URL format for Microsoft Graph API
    url = "/v1.0/me/messages/#{attachment.message.provider_message_id}/attachments/#{attachment.attachment_id}/$value"

    response = conn.get(url)

    if response.success?
      # Want to render in browser always, at least for now
      disposition_type = "inline"

      # Send the attachment data to the browser
      send_data response.body,
        filename: attachment.filename,
        type: attachment.mime_type,
        disposition: disposition_type
    else
      Rails.logger.error "Failed to fetch Outlook attachment: #{response.status} - #{response.body}"
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
  end
end
