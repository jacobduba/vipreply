# frozen_string_literal: true

require "google/apis/gmail_v1"
require "date"

class SessionsController < ApplicationController
  skip_before_action :authorize_has_account

  def new
    redirect_to root_path if session[:account_id]
  end

  def destroy
    reset_session
    redirect_to login_path
  end

  def googleAuth
    # https://github.com/zquestz/omniauth-google-oauth2?tab=readme-ov-file#auth-hash
    auth_hash = request.env["omniauth.auth"]

    account = Account.find_by(provider: auth_hash.provider, uid: auth_hash.uid)

    account ||= Account.new

    account.provider = auth_hash.provider # google_oauth2
    account.uid = auth_hash.uid
    account.access_token = auth_hash.credentials.token
    # Refresh tokens are only given when the user consents (typically the first time) thus ||=
    account.refresh_token ||= auth_hash.credentials.refresh_token
    account.expires_at = Time.at(auth_hash.credentials.expires_at)
    account.email = auth_hash.info.email
    account.name = auth_hash.info.name
    account.first_name = auth_hash.info.first_name
    account.last_name = auth_hash.info.last_name

    begin
      account.save!
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error e
      redirect_to "/login"
    end

    # Supposed to only setup inbox if not setup...
    # unless account.inbox
    #   setup_inbox account
    # end

    # ... but for testing delete inbox and setup every time
    account&.inbox&.destroy
    setup_inbox account

    session[:account_id] = account.id
    redirect_to "/inbox"
  end

  private

  def setup_inbox(account)
    puts "Setting up inbox"
    inbox = account.create_inbox

    # Initialize Gmail API client
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = account.google_credentials
    user_id = "me"

    # Fetch thread IDs with a single request
    threads_response = gmail_service.list_user_threads(user_id, max_results: 50)
    thread_info = threads_response.threads.map do |thread|
      {id: thread.id, snippet: thread.snippet}
    end

    gmail_service.batch do |gmail_service|
      thread_info.each do |thread|
        gmail_service.get_user_thread("me", thread[:id]) do |res, err|
          if err
            puts "Error fetching thread #{thread[:id]}: #{err.message}"
          else
            cache_topic(res, thread[:snippet], inbox)
          end
        end
      end
    end
  end

  def cache_topic(response_body, snippet, inbox)
    # Extract fields
    thread_id = response_body.id
    first_message = response_body.messages.first
    first_message_headers = first_message.payload.headers
    last_message = response_body.messages.last
    last_message_headers = last_message.payload.headers
    messages = response_body.messages

    # Extract relevant fields
    date = DateTime.parse(last_message_headers.find { |h| h.name.downcase == "date" }.value)
    subject = first_message_headers.find { |h| h.name.downcase == "subject" }.value
    from_header = last_message_headers.find { |h| h.name.downcase == "from" }.value
    from = from_header.include?("<") ? from_header[/<([^>]+)>/, 1] : from_header
    to_header = last_message_headers.find { |h| h.name.downcase == "to" }.value
    to = to_header.include?("<") ? to_header[/<([^>]+)>/, 1] : to_header

    do_not_reply = from == inbox.account.email
    message_count = response_body.messages.count
    # Save thread details
    begin
      topic = inbox.topics.create!(
        thread_id: thread_id,
        snippet: snippet,
        date: date,
        subject: subject,
        from: from,
        to: to,
        do_not_reply: do_not_reply,
        message_count: message_count
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save topic: #{e.message}"
      return
    end

    puts("Adding messages")

    messages.each do |message|
      cache_message(topic, message)
    end
  end

  def cache_message(topic, message)
    headers = message.payload.headers
    message_id = message.id
    date = DateTime.parse(headers.find { |h| h.name.downcase == "date" }.value)
    subject = headers.find { |h| h.name.downcase == "subject" }.value
    from = headers.find { |h| h.name.downcase == "from" }.value
    to = headers.find { |h| h.name.downcase == "to" }.value
    internal_date = Time.at(message.internal_date / 1000).to_datetime

    collected_parts = extract_parts(message.payload)

    plaintext = collected_parts[:plain]
    html = collected_parts[:html]
    attachments = collected_parts[:attachments]

    begin
      msg = topic.messages.create!(
        message_id: message_id,
        date: date,
        subject: subject,
        from: from,
        to: to,
        internal_date: internal_date,
        plaintext: plaintext,
        html: html
      )
      attachments.each do |attachment|
        msg.attachments.create!(
          attachment_id: attachment[:attachment_id],
          content_id: attachment[:content_id],
          filename: attachment[:filename],
          mime_type: attachment[:mime_type],
          size: attachment[:size]
        )
      end
      puts message.replace_cids_with_urls(request)
    end
  end

  def extract_parts(part)
    result = {
      plain: nil,
      html: nil,
      attachments: []
    }

    if part.mime_type.start_with?("multipart/")
      part.parts.each do |subpart|
        subresult = extract_parts(subpart)
        result[:plain] ||= subresult[:plain]
        result[:html] ||= subresult[:html]
        result[:attachments].concat(subresult[:attachments])
      end
    elsif part.mime_type == "text/plain"
      result[:plain] = part.body.data
    elsif part.mime_type == "text/html"
      result[:html] = part.body.data
    else
      content_disposition = part.headers.find { |h| h.name == "Content-Disposition" }&.value
      if content_disposition&.start_with?("attachment") || part.filename
        cid_header = part.headers.find { |h| h.name == "Content-ID" }
        cid = cid_header&.value
        result[:attachments] << {
          attachment_id: part.body.attachment_id,
          content_id: cid ? "cid:" + cid[1..-2] : nil,
          filename: part.filename,
          mime_type: part.mime_type,
          size: (part.body.size / 1024.0).round
        }
      end
    end

    result
  end

  def login_params
    params.require(:account).permit(:auth_hashname, :password)
  end
end
