# frozen_string_literal: true

require "google/apis/gmail_v1"

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
      setup_inbox account
      session[:account_id] = account.id
      redirect_to "/inbox"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error e
      redirect_to "/login"
    end
  end

  private

  def setup_inbox(account)
    puts "Setting up inbox"
  
    # Initialize Gmail API client
    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = account.google_credentials
    user_id = 'me'
  
    # Fetch thread IDs with a single request
    threads_response = service.list_user_threads(user_id, max_results: 50)
    thread_ids = threads_response.threads.map(&:id)
  
    # Prepare the batch request body
    batch_body = thread_ids.map.with_index do |thread_id, index|
      <<~EOS
        --batch_boundary
        Content-Type: application/http
        Content-ID: <item#{index}>
  
        GET /gmail/v1/users/#{user_id}/threads/#{thread_id}
      EOS
    end.join("\n") + "\n--batch_boundary--"
  
    # Perform the batch HTTP request
    batch_url = URI('https://gmail.googleapis.com/batch')
    http = Net::HTTP.new(batch_url.host, batch_url.port)
    http.use_ssl = true
  
    request = Net::HTTP::Post.new(batch_url)
    request['Authorization'] = "Bearer #{account.google_credentials.access_token}"
    request['Content-Type'] = 'multipart/mixed; boundary=batch_boundary'
    request.body = batch_body
  
    response = http.request(request)
  
    # Parse the batch response
    thread_details = parse_batch_response(response.body)
  
    # Output the result to the console
    puts JSON.pretty_generate(thread_details)
  end
  
  def parse_batch_response(response_body)
    # Define boundary from response
    boundary_match = response_body.match(/--batch_[\w-]+/)
    boundary = boundary_match[0] if boundary_match
    raise "Batch boundary not found" unless boundary
  
    # Split responses using the boundary
    responses = response_body.split(boundary).map(&:strip)
  
    thread_details = {}
  
    responses.each do |response|
      # Skip empty or invalid parts
      next if response.empty? || !response.include?('200 OK')
  
      # Extract JSON from the response part
      json_start = response.index('{')
      json_end = response.rindex('}')
      next unless json_start && json_end 
  
      json_body = response[json_start..json_end]
  
      # Parse the JSON data
      begin
        thread_data = JSON.parse(json_body)
      rescue JSON::ParserError => e
        puts "Error parsing JSON: #{e.message}"
        next
      end
  
      # Extract thread details
      thread_id = thread_data['id']
      last_message = thread_data['messages'][-1]
      headers = last_message['payload']['headers']
  
      # Extract relevant fields
      date = headers[16]['value']
      subject = headers[22]['value']
      from = headers[23]['value']
      to = headers[24]['value']
      body_data = last_message['payload']['parts']&.dig(0, 'body', 'data')
      decoded_body = body_data ? Base64.urlsafe_decode64(body_data) : nil
  
      # Store thread details
      thread_details[thread_id] = {
        messages: thread_data['messages'].map { |msg| msg['id'] },
        date: date,
        subject: subject,
        from: from,
        to: to,
        body: decoded_body
      }
    end
  
    puts thread_details
  end

  def login_params
    params.require(:account).permit(:auth_hashname, :password)
  end
end
