# frozen_string_literal: true

class AttachmentsController < ApplicationController
  before_action :initialize_gmail_service

  def show
    # Find the attachment by ID or return a 404 error page
    attachment = Attachment.find_by(id: params[:id])

    unless attachment
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
      return
    end

    user_id = "me"
    message_id = attachment.message.message_id
    attachment_id = attachment.attachment_id

    response = @gmail_service.get_user_message_attachment(user_id, message_id, attachment_id)

    attachment_data = response.data
    # Want to render in browser always, at least for now
    disposition_type = "inline"
    # disposition_type = attachment.content_id ? "inline" : "attachment"

    # Send the file to the browser
    send_data attachment_data,
      filename: attachment.filename,
      type: attachment.mime_type,
      disposition: disposition_type
  end

  private

  def initialize_gmail_service
    @gmail_service = Google::Apis::GmailV1::GmailService.new
    @gmail_service.authorization = @account.google_credentials
  end
end
