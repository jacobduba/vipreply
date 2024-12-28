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
            parse_batch_response(res, thread[:snippet], inbox)
          end
        end
      end
    end
  end

  def parse_batch_response(response_body, snippet, inbox)
    # Extract fields
    thread_id = response_body.id
    last_message = response_body.messages.last
    headers = last_message.payload.headers

    # Extract relevant fields
    date = DateTime.parse(headers.find { |h| h.name.downcase == "date" }.value)
    subject = headers.find { |h| h.name.downcase == "subject" }.value
    from = headers.find { |h| h.name.downcase == "from" }.value
    to = headers.find { |h| h.name.downcase == "to" }.value

    # Save thread details
    begin
      inbox.topics.create!(
        thread_id: thread_id,
        snippet: snippet,
        messages: response_body.messages.map(&:id), # Store message IDs
        date: date,
        subject: subject,
        from: from,
        to: to
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save topic: #{e.message}"
    end
  end

  def login_params
    params.require(:account).permit(:auth_hashname, :password)
  end
end
