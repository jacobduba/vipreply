# frozen_string_literal: true

require "google/apis/gmail_v1"

class AttachmentsController < ApplicationController
  before_action :set_account

  def show
    # Find the attachment by ID
    attachment = Attachment.find_by(id: params[:id])

    if attachment.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
      return
    end

    # Use Gmail API to fetch the attachment data
    user_id = "me"
    message_id = attachment.message.message_id
    attachment_id = attachment.attachment_id

    begin
      # Fetch the raw attachment data
      response = @gmail_service.get_user_message_attachment(user_id, message_id, attachment_id)
      attachment_data = response.data

      disposition_type = attachment.content_id ? "inline" : "attachment"

      # Send the file to the browser
      send_data attachment_data,
        filename: attachment.filename,
        type: attachment.mime_type,
        disposition: disposition_type
    rescue => e
      puts e
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
  end

  private

  def set_account
    @account = Account.find(session[:account_id])
    unless @account
      redirect_to login_path, alert: "Please log in to access this resource."
      return
    end

    @gmail_service = Google::Apis::GmailV1::GmailService.new
    @gmail_service.authorization = @account.google_credentials
  end
end
