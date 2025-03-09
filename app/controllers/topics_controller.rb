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

    # TODO — cache this?
    @has_templates = @account.templates.exists?

    # If true, call navigation controller to do history.back() else hard link
    # history.back() preserves scroll
    @from_inbox = request.referrer == root_url
  end

  def send_email
    email_body = params[:email]
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

    # Create quoted text
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

      <p>On #{Time.now.strftime("%a, %b %d, %Y at %I:%M %p")}, #{most_recent_message.from_name} wrote:</p>
      <blockquote style="border-left: 1px solid #ccc; margin-left: 10px; padding-left: 10px;">
        #{most_recent_message.html}
      </blockquote>
    HTML

    in_reply_to = most_recent_message.message_id
    references = @topic.messages.order(date: :asc).map(&:message_id).join(" ")

    # Send email based on provider
    case @inbox.provider
    when "google_oauth2"
      send_gmail_reply(from, to, subject, email_body_plaintext, email_body_html, in_reply_to, references)
    when "microsoft_office365"
      send_outlook_reply(from, to, subject, email_body_plaintext, email_body_html, most_recent_message)
    end

    # Update the inbox
    UpdateFromHistoryJob.perform_now @inbox.id

    # Update template associations if any were used
    if @topic.templates.any?
      if most_recent_message
        # Ensure message embedding exists
        MessageEmbedding.create_for_message(most_recent_message) unless most_recent_message.message_embedding

        if most_recent_message.message_embedding
          @topic.templates.each do |template|
            template.message_embeddings << most_recent_message.message_embedding unless template.message_embeddings.include?(most_recent_message.message_embedding)
          end
        end
      end
    end

    @topic.update(generated_reply: "", templates: [])

    redirect_to topic_path(@topic)
  end

  def change_status
    new_status = @topic.has_reply? ? :needs_reply : :has_reply

    @topic.update(status: new_status)

    render turbo_stream: turbo_stream.replace("change_status_button", partial: "topics/change_status_button")
  end

  def template_selector_dropdown
    # Get all templates from the account, ordered by most recently used
    @templates = @topic.list_templates_by_relevance
  end

  def change_templates_regenerate_response
    template_ids = params.dig(:template_ids) || []
    valid_templates = @account.templates.where(id: template_ids)

    if valid_templates.count != template_ids.size || @account != @topic.inbox.account
      render file: "#{Rails.root}/public/404.html", status: :not_found
      return
    end

    @topic.templates = valid_templates
    refresh_topic_reply(@topic)
  end

  def update_templates_regenerate_reply
    if params[:templates].blank?
      refresh_topic_reply(@topic)
      return
    end

    templates_params = params.expect(templates: [[:output]])

    changed_templates = templates_params.keys.map(&:to_i)

    ActiveRecord::Base.transaction do
      errors = {}

      Template.where(id: changed_templates).each do |template|
        unless template.update(templates_params[template.id.to_s])
          errors[index] = template.errors.full_messages
        end

        if errors.any?
          raise ActiveRecord::Rollback, errors
        end
      end
    end

    refresh_topic_reply(@topic)
  end

  def remove_template
    template_id = params[:template_id].to_i

    if @topic.template_ids.exclude?(template_id)
      render plain: "Template not attached to topic", status: :not_found
      return
    end

    @topic.templates.delete(template_id)
    @topic.save
    render turbo_stream: [
      turbo_stream.replace("template_form", partial: "topics/template_form", locals: {
        input_errors: [],
        output_errors: [],
        topic: @topic
      })
    ]
  end

  # Debug Find Template method
  # TODO Remove???? Idk what this is used for
  def find_template
    # This will calculate and assign the best templates based on the latest message.
    @topic.find_best_templates

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "template-selector-body",
          partial: "topics/template_selector_body",
          locals: {templates: @topic.templates}
        )
      end
      format.html { redirect_to topic_path(@topic) }
    end
  end

  private

  def send_gmail_reply(from, to, subject, plaintext, html, in_reply_to, references)
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = @inbox.credentials

    # Build the email message
    email = Mail.new do
      from from
      to to
      subject subject

      text_part do
        body plaintext
      end

      html_part do
        content_type "text/html; charset=UTF-8"
        body html
      end

      # Add headers to attach the email to the thread
      if in_reply_to
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
    end
  end

  def send_outlook_reply(from, to, subject, plaintext, html, reply_to_message)
    # Clean recipient email from potential format "Name <email@example.com>"
    to_email = (to =~ /<(.+)>/) ? $1 : to

    conn = @inbox.graph_client  # Use inbox's graph_client method

    draft_response = conn.post("/v1.0/me/messages/#{reply_to_message.provider_message_id}/createReply")
    unless draft_response.success?
      Rails.logger.error "Failed to create draft reply: #{draft_response.body}"
      return
    end

    draft_message = draft_response.body
    message_id = draft_message["id"]

    message_data = {
      subject: subject,
      body: {
        contentType: "html",
        content: html
      },
      toRecipients: [
        {
          emailAddress: {
            address: to_email
          }
        }
      ],
      conversationId: @topic.thread_id
    }

    update_response = conn.patch("/v1.0/me/messages/#{message_id}") do |req|
      req.body = message_data
    end

    unless update_response.success?
      Rails.logger.error "Failed to update draft reply: #{update_response.body}"
      return
    end

    send_response = conn.post("/v1.0/me/messages/#{message_id}/send")
    unless send_response.success?
      Rails.logger.error "Failed to send Outlook message: #{send_response.body}"
    end
  end

  def set_topic
    @topic = if ["show", "remove_template"].include?(action_name)
      Topic.includes(:templates).find(params[:id])
    else
      Topic.find(params[:id])
    end
  end

  def authorize_account_owns_topic
    unless @topic.inbox.account == @account
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
  end
end
