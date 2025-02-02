class TopicsController < ApplicationController
  include ActionView::Helpers::TextHelper

  before_action :set_topic
  before_action :authorize_account_owns_topic

  include GeneratorConcern

  def show
    # iframes are used to isolate email code
    # Why??? I do not trust myself to securely sanitize emails
    # Yes. this makes the user experience worse
    # More: https://security.stackexchange.com/a/134587

    @messages = @topic.messages.order(date: :asc).includes(:attachments)
    @template = @topic.template
    @generated_reply = if @topic.skipped_no_reply_needed?
      ""
    else
      @topic.generated_reply
    end
    # TODO — cache this?
    @has_templates = @account.inbox.templates.exists?

    # If true, call navigation controller to do history.back() else hard link
    # history.back() preserves scroll
    @from_inbox = request.referrer == root_url
  end

  def regenerate_reply
    handle_regenerate_reply(params[:id])
  end

  def send_email
    # Extract the email body directly from params[:email]
    email_body = params[:email]

    # Get the most recent message in the topic
    most_recent_message = @topic.messages.order(date: :desc).first
    if most_recent_message.nil?
      Rails.logger.info "Cannot send email: No messages found in this topic."
      redirect_to topic_path(@topic) and return
    end

    # Determine the 'from' and 'to' fields using the most recent message
    from = "#{@account.name} <#{@account.email}>"
    to = if most_recent_message.from_email == @account.email
      most_recent_message.to
    else
      most_recent_message.from
    end

    subject = "Re: #{@topic.subject}"

    quoted_plaintext = most_recent_message.plaintext.lines.map do |line|
      if line.starts_with?(">")
        ">#{line}"
      else
        "> #{line}"
      end
    end.join

    email_body_plaintext = <<~PLAINTEXT
      #{email_body}

      On #{Time.now.strftime("%a, %b %d, %Y at %I:%M %p")}, #{most_recent_message.from_name} wrote:
      #{quoted_plaintext}
    PLAINTEXT

    email_body_html = <<~HTML
      #{simple_format(email_body)}

      On #{Time.now.strftime("%a, %b %d, %Y at %I:%M %p")}, #{most_recent_message.from_name} wrote:
      <blockquote>
        #{most_recent_message.html}
      </blockquote>
    HTML

    in_reply_to = most_recent_message.message_id
    references = @topic.messages.order(date: :asc).map(&:message_id).join(" ")

    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = @account.google_credentials

    # Build the email message
    email = Mail.new do
      from from
      to to
      subject subject

      text_part do
        body quoted_plaintext # Plain text version
      end

      html_part do
        content_type "text/html; charset=UTF-8"
        body email_body_html
      end

      # Add headers to attach the email to the thread
      if most_recent_message.message_id
        header["In-Reply-To"] = in_reply_to
        header["References"] = references
      end
    end

    # Encode the email message
    raw_message = email.encoded

    # Attach the email to the thread by setting `threadId`
    begin
      message_object = Google::Apis::GmailV1::Message.new(
        raw: raw_message,
        thread_id: @topic.thread_id
      )
      gmail_service.send_user_message("me", message_object)
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Failed to send email: #{e.message}"
      return
    end

    inbox = @account.inbox
    UpdateFromHistoryJob.perform_now inbox.id

    template = @topic.template

    if template
      Example.create!(
        message: most_recent_message,
        template: template,
        inbox: inbox
      )
    end

    # Redirect back to the topic page
    redirect_to topic_path(@topic)
  end

  def change_status
    new_status = @topic.has_reply? ? :needs_reply : :has_reply

    @topic.update(status: new_status)

    render turbo_stream: turbo_stream.replace("change_status_button", partial: "topics/change_status_button")
  end

  def template_selector
    @templates = @topic.inbox.templates
  end

  def change_template
    template = Template.find(topic_params[:template_id])

    unless template.inbox.account == @account
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end

    redirect_to topic_path(@topic)
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

  def topic_params
    params.require(:topic).permit(:template_id)
  end
end
