# frozen_string_literal: true

class TopicsController < ApplicationController
  include ActionView::Helpers::TextHelper
  include GeneratorConcern

  before_action :authorize_account
  before_action :require_gmail_permissions
  before_action :require_subscription
  before_action :set_topic
  before_action :authorize_account_owns_topic

  def show
    @messages = @topic.messages.order(date: :asc).includes(:attachments)

    @templates = @topic.templates if @topic.requires_action?

    # If true, back button in show does history.back() instead of hard link to inbox.
    # b/c history.back() preserves scroll
    @from_inbox = request.referrer == inbox_url
  end

  def send_email
    reply_text = params[:email]

    most_recent_message = @topic.messages.order(date: :desc).first
    if most_recent_message.nil?
      Rails.logger.info "Cannot send email: No messages found in this topic."
      redirect_to topic_path(@topic) and return
    end

    raw_email_reply = most_recent_message.create_reply(reply_text, @account)

    @account.with_gmail_service do |service|
      message_object = Google::Apis::GmailV1::Message.new(
        raw: raw_email_reply,
        thread_id: @topic.thread_id
      )
      service.send_user_message("me", message_object)
    end

    inbox_id = @account.inbox.id
    thread_id = @topic.thread_id
    FetchGmailThreadJob.perform_now inbox_id, thread_id

    @topic.templates.each do |template|
      unless template.message_embeddings.include?(most_recent_message.message_embedding)
        template.message_embeddings << most_recent_message.message_embedding
      end
    end

    @topic.update(generated_reply: "", templates: [])

    redirect_to topic_path(@topic)
  end

  def move_to_no_action_required
    @topic.move_to_no_action_required!
    redirect_to @topic
  end

  def move_to_requires_action
    @topic.move_to_requires_action!
    redirect_to @topic
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
    template_params = params.expect(template: [ :output ])

    @template = @topic.inbox.templates.new(template_params)

    unless @template.save
      @output_errors = @template.errors[:output] || []
      render :create_template_dropdown
      return
    end

    @topic.templates << @template

    refresh_topic_reply(@topic)
  end

  def change_templates_regenerate_response
    template_ids = params.expect(template_ids: [])

    valid_templates = @account.inbox.templates.where(id: template_ids)

    if valid_templates.count != template_ids.size || @account != @topic.inbox.account
      render file: "#{Rails.root}/public/404.html", status: :not_found
      return
    end

    @topic.templates = valid_templates

    refresh_topic_reply(@topic)
  end

  # This is for the template form where users edit template text and click "Save template & regenerate reply"
  def update_templates_regenerate_reply
    if params[:templates].blank?
      refresh_topic_reply(@topic)
      return
    end

    templates_params = params.expect(templates: [ [ :output ] ])

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
    @topic.save!

    refresh_topic_reply(@topic)
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
