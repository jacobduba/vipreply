require "google/apis/gmail_v1"

class TopicsController < ApplicationController
  before_action :set_topic
  before_action :authorize_account_owns_topic

  include GeneratorConcern

  def show
    @messages = @topic.messages.order(date: :asc)

    # iframes are used to isolate email code
    # Why??? I do not trust myself to securely sanitize emails
    # Yes. this makes the user experience worse
    # More: https://security.stackexchange.com/a/134587

    @template = @topic.template
    @generated_reply = if @topic.skipped_no_reply_needed?
      ""
    else
      @topic.generated_reply
    end
  end

  def regenerate_reply
    handle_regenerate_reply(params[:id])
  end

  def send_email
    # Find the topic and ensure ownership
    topic = Topic.find(params[:id])
    unless topic.inbox.account == @account
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
      return
    end

    # Extract the email body directly from params[:email]
    email_body = params[:email]

    # Get the most recent message in the topic
    most_recent_message = topic.messages.order(date: :desc).first
    if most_recent_message.nil?
      flash[:alert] = "Cannot send email: No messages found in this topic."
      redirect_to topic_path(topic) and return
    end

    # Fetch Gmail message metadata to get accurate headers
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = @account.google_credentials

    gmail_metadata = gmail_service.get_user_message("me", most_recent_message.message_id, format: "metadata", metadata_headers: ["Message-ID", "References"])
    message_id_header = gmail_metadata.payload.headers.find { |h| h.name == "Message-ID" }&.value
    references_header = gmail_metadata.payload.headers.find { |h| h.name == "References" }&.value

    # Determine the 'from' and 'to' fields using the most recent message
    from_email = @account.email # Always use the logged-in account's email as the sender
    to_email = if most_recent_message.from == @account.email
      most_recent_message.to # If the most recent message was sent by us, reply to the recipient
    else
      most_recent_message.from # Otherwise, reply to the sender of the most recent message
    end

    # Build the email message
    email = Mail.new do
      from from_email
      to to_email
      subject "Re: #{topic.subject}" # Match the original subject for threading
      body email_body

      # Add headers to attach the email to the thread
      if message_id_header
        header["In-Reply-To"] = message_id_header
        header["References"] = references_header ? "#{references_header} #{message_id_header}" : message_id_header
      end
    end

    # Encode the email message
    raw_message = email.encoded

    puts "Sending email:"
    puts raw_message

    # Attach the email to the thread by setting `threadId`
    begin
      message_object = Google::Apis::GmailV1::Message.new(
        raw: raw_message,
        thread_id: topic.thread_id # Use the correct thread ID
      )
      gmail_service.send_user_message("me", message_object)
      flash[:notice] = "Email sent successfully to #{to_email}!"
    rescue Google::Apis::ClientError => e
      flash[:alert] = "Failed to send email: #{e.message}"
    end

    # Redirect back to the topic page
    redirect_to topic_path(topic)
  end

  private

  def set_topic
    @topic = Topic.find(params[:id])
  end

  def authorize_account_owns_topic
    unless @topic.inbox.account == @account
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
  end
end
