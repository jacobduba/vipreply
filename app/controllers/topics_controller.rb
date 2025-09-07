# frozen_string_literal: true

class TopicsController < ApplicationController
  include ActionView::Helpers::TextHelper

  before_action :authorize_account
  before_action :require_gmail_permissions
  before_action :require_subscription
  before_action :set_topic
  before_action :authorize_account_owns_topic

  include GeneratorConcern

  def show
    # iframes are used to isolate email code
    # Why??? I do not trust myself to securely sanitize emails
    # Yes. this makes the user experience worse
    # More: https://security.stackexchange.com/a/134587

    @messages = @topic.messages.order(date: :asc).includes(:attachments)
    @templates_with_confidence = @topic.template_topics.includes(:template)

    # If true, call navigation controller to do history.back() else hard link
    # history.back() preserves scroll
    @from_inbox = request.referrer == inbox_url
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
    from_address = "#{@account.name} <#{@account.email}>"
    to_address = if most_recent_message.from_email == @account.email
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

      On #{Time.current.strftime("%a, %b %d, %Y at %I:%M %p")}, #{most_recent_message.from_name} wrote:
      #{quoted_plaintext}
    PLAINTEXT

    # TODO remove this stupid div around and just give blockquote id like gmail
    email_body_html = <<~HTML
      #{simple_format(email_body)}

      <div class="vip_quote">
        <p>On #{Time.current.strftime("%a, %b %d, %Y at %I:%M %p")}, #{most_recent_message.from_name} wrote:</p>
        <blockquote>
          #{most_recent_message.html}
        </blockquote>
      </div>
    HTML

    in_reply_to = most_recent_message.message_id
    references = @topic.messages.order(date: :asc).map(&:message_id).join(" ")

    # Build the email message
    email = Mail.new do
      from from_address
      to to_address
      subject subject

      text_part do
        body email_body_plaintext
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

    # Send the email using Gmail API
    @account.with_gmail_service do |service|
      message_object = Google::Apis::GmailV1::Message.new(
        raw: raw_message,
        thread_id: @topic.thread_id
      )
      service.send_user_message("me", message_object)
    end

    inbox_id = @account.inbox.id
    thread_id = @topic.thread_id
    FetchGmailThreadJob.perform_now inbox_id, thread_id

    if @topic.templates.any?
      if most_recent_message
        most_recent_message.ensure_embedding_exists # TODO: do i need to do this? wait wtf is going on here...

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
    # Get all templates from the inbox, ordered by most recently used
    # We need to update this since templates are now connected to messages through message_embeddings
    @templates = @topic.list_templates_by_relevance
  end

  def new_template_dropdown
    @template = @topic.inbox.templates.new
    @output_errors = []
    render :create_template_dropdown
  end

  def create_template_dropdown
    template_params = params.expect(template: [:output])

    @template = @topic.inbox.templates.new(template_params)

    unless @template.save
      @output_errors = @template.errors[:output] || []
      render :create_template_dropdown
      return
    end

    @templates_with_confidence = [TemplateTopic.new(template_id: @template.id, topic_id: @topic.id, confidence_score: 0)]
    refresh_topic_reply(@topic)
    nil
  end

  def change_templates_regenerate_response
    template_ids, confidence_scores = params.expect(template_ids: [], confidence_scores: {})

    # The confidence scores are purely cosmetic, if that changes
    # obviously we should not be loading them from a form in the dom
    validated_scores = {}
    confidence_scores.each do |template_id, score|
      validated_scores[template_id] = score.to_f.clamp(0.0, 1.0)
    end

    valid_templates = @account.inbox.templates.where(id: template_ids)

    if valid_templates.count != template_ids.size || @account != @topic.inbox.account
      render file: "#{Rails.root}/public/404.html", status: :not_found
      return
    end

    # Yeah I know it's slow but there shouldn't be too many records. I want validations because that's the Rails way
    TemplateTopic.where(topic_id: @topic.id).destroy_all
    valid_templates.each do |template|
      confidence_score = validated_scores[template.id.to_s] || 0.0
      TemplateTopic.create!(template: template, topic: @topic, confidence_score: confidence_score)
    end

    # Reload templates with confidence after updating associations
    @templates_with_confidence = @topic.template_topics.includes(:template)

    refresh_topic_reply(@topic)
  end

  # This is for the template form where users edit template text and click "Save template & regenerate reply"
  def update_templates_regenerate_reply
    if params[:templates].blank?
      @templates_with_confidence = []
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

    @templates_with_confidence = @topic.template_topics.includes(:template)

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

    @templates_with_confidence = @topic.template_topics.includes(:template)

    render turbo_stream: [
      turbo_stream.replace("template_form", partial: "topics/template_form", locals: {
        output_errors: [],
        topic: @topic
      })
    ]
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
