# frozen_string_literal: true

class Topic < ApplicationRecord
  # Number of days to consider a topic old during import
  OLD_EMAIL_DAYS_THRESHOLD = 3

  belongs_to :inbox
  has_many :template_topics, dependent: :destroy
  has_many :templates, through: :template_topics

  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages

  enum :status, %i[
    requires_action_human_needed
    no_action_required_marked_by_user
    no_action_required_marked_by_ai
    no_action_required_awaiting_customer
    no_action_required_is_old_email
    requires_action_ai_auto_replied
  ]

  scope :not_spam, -> { where(is_spam: false) }

  after_commit :broadcast_inbox_refresh

  def no_action_required?
    self.no_action_required_marked_by_user? ||
    self.no_action_required_marked_by_ai? ||
    self.no_action_required_awaiting_customer? ||
    self.no_action_required_is_old_email?
  end

  def requires_action?
    self.requires_action_human_needed? || self.requires_action_ai_auto_replied?
  end

  def auto_moved?
    self.no_action_required_marked_by_ai? || self.no_action_required_is_old_email?
  end

  # Maintain compatibility with views that may use from/to
  def from
    from_name.present? ? "#{from_name} <#{from_email}>" : from_email.to_s
  end

  def to
    to_name.present? ? "#{to_name} <#{to_email}>" : to_email.to_s
  end

  def template_attached?
    templates.any?
  end

  def auto_select_templates
    latest_message = messages.order(date: :desc).first
    return Template.none unless latest_message&.message_embedding&.embedding

    target_embedding = latest_message.message_embedding.embedding
    target_embedding_literal = ActiveRecord::Base.connection.quote(target_embedding.to_s)

    top_3_embeddings = MessageEmbedding
      .joins(:templates)
      .where(templates: { inbox_id: inbox.id })
      .select(<<~SQL)
        message_embeddings.id as id,
        message_embeddings.message_id as message_id,
        message_embeddings.embedding <=> #{target_embedding_literal}::vector AS similarity
      SQL
      .order("similarity ASC")
      .limit(3)

    message_embeddings = MessageEmbedding
      .from(top_3_embeddings, :message_embeddings)
      .includes(:message, :templates) # need to PRELOAD EVERYTHING thanks to active record not working in async (which we do later)
      .order("similarity ASC")

    current_message = latest_message.to_s_anon

    candidate_template_sets = Sync do
      message_embeddings.map do |message_embedding|
        Async do
          past_message = message_embedding.message.to_s_anon

          response = OpenRouterClient.chat(
            models: [ "openai/gpt-5:nitro" ],
            messages: [
              {
                role: "system",
                content: "Do these two customer emails require the exact same template reply and/or action taken? Only reply 'yes' or 'no.'"
              },
              {
                role: "user",
                content: <<~PROMPT
                  EMAIL 1:
                  #{current_message}
                  EMAIL 2:
                  #{past_message}
                PROMPT
              }
            ],
            posthog_user_id: inbox.account.id
          )

          same_cards_required = response["choices"][0]["message"]["content"].downcase == "yes"

          if same_cards_required
            message_embedding.templates
          end
        end
      end.map(&:wait)
    end

    # finds unique sets of candidate templates (which are lists of ids of templates)
    chosen_templates = candidate_template_sets
      .flatten
      .compact
      .uniq

    return if chosen_templates.empty?

    template_prompt = chosen_templates.map.with_index { |t, i| "Smart template ##{i + 1}:\n#{t.output}" }.join("\n\n")

    response = OpenRouterClient.chat(
      models: [ "openai/gpt-5:nitro" ],
      messages: [
        {
          role: "system",
           content: "Do you have enough information from the smart cards to answer the customer email? Only reply with 'yes' or 'no.'"
        },
        {
          role: "user",
          content: <<~PROMPT
            SMART TEMPLATES:
            #{template_prompt}
           EMAIL:
            #{latest_message}
          PROMPT
        }
      ],
      posthog_user_id: inbox.account.id
    )

    templates_answer_email = response["choices"][0]["message"]["content"].downcase == "yes"

    self.templates = chosen_templates if templates_answer_email
  end

  def list_templates_by_relevance
    latest_message = messages.order(date: :desc).first
    # List all templates when no embedding
    # This is the case for messages loaded before templates v2
    # Could probaly remove this in a month or two
    return inbox.templates unless latest_message&.message_embedding&.embedding

    target_embedding = latest_message.message_embedding.embedding
    target_embedding_literal = ActiveRecord::Base.connection.quote(target_embedding.to_s)

    inbox.templates
      .left_joins(:message_embeddings)
      .select(<<~SQL)
        templates.id AS id,
        templates.output AS output,
        MIN(message_embeddings.embedding <=> #{target_embedding_literal}::vector) AS similarity
      SQL
      .group("templates.id, templates.output")
      .order("similarity ASC NULLS LAST")
  end

  # Debugging helper to identify the message most similar to the latest message
  # that caused this template's similiarity score for the current topic.
  def debug_closest_message_for_template(template_id)
    latest_message = messages.order(date: :desc).first
    # List all templates when no embedding
    # This is the case for messages loaded before templates v2
    # Could probaly remove this in a month or two
    return inbox.templates unless latest_message&.message_embedding&.embedding

    target_embedding = latest_message.message_embedding.embedding
    target_embedding_literal = ActiveRecord::Base.connection.quote(target_embedding.to_s)

    Message
      .joins(message_embedding: :templates)
      .where(templates: { id: template_id })
      .select("messages.*, (message_embeddings.embedding <=> #{target_embedding_literal}::vector) AS distance")
      .order("distance")
      .first
  end

  def latest_message
    messages.order(date: :desc).first
  end

  def attached_templates_plus_email_plus_reply
    <<~PROMPT
      SMART TEMPLATES:
      #{templates_to_formatted_string}
      EMAIL:
      #{latest_message}
      GENERATED REPLY:
      #{generated_reply}
    PROMPT
  end

  def generate_reply
    return if templates.empty?

    response = OpenRouterClient.chat(
      models: [ "openai/gpt-5-chat:nitro" ],
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are an AI agent answering customer support emails for a business.
            Your goal is to serve the customer by providing helpful answers.
            CRITICAL: Do NOT make up, invent, or fabricate any information. Only use facts explicitly stated in the provided smart cards. If something is not directly mentioned in the smart cards, do not include it.
            If the template contains a link, make sure you provide a link or hyperlink to the customer.
            Do not include any email signature, closing salutation, or sign-off at the end of the email. End the email with the main content only.
            Always start your response with a greeting followed by the customer's name.

            PERSONALITY:
              - You believe everyone is an equal, so you do not praise or criticize anyone.
              - Everyone deserves respect and kindness.
              - You value giving great service to humans.
          PROMPT
        },
        {
          role: "user",
          content: <<~PROMPT
            SMART TEMPLATES:
            #{templates_to_formatted_string}
            EMAIL:
            #{latest_message}
          PROMPT
        }
      ],
      posthog_user_id: inbox.account.id
    )

    self.generated_reply = response["choices"][0]["message"]["content"].strip.tr("—", " - ")
  end

  def templates_to_formatted_string
    templates.map.with_index { |t, i| "Smart template ##{i + 1}:\n#{t.output}" }.join("\n\n")
  end

  def auto_reply_if_safe
    return unless templates.any? && templates.all?(&:auto_reply)
    return if generated_reply.blank?

    return if hallucinated_reply?

    send_reply!(generated_reply)

    update!(status: :requires_action_ai_auto_replied)
  end

  def hallucinated_reply?
    response = OpenRouterClient.chat(
      models: [ "openai/gpt-5-chat:nitro" ],
      messages: [
        {
          role: "system",
          content: "Does generated reply introduce any hallucinations? Only reply 'yes' or 'no'"
        },
        {
          role: "user",
          content: <<~PROMPT
            SMART TEMPLATES:
            #{templates_to_formatted_string}
            EMAIL:
            #{latest_message}
            GENERATED REPLY:
            #{generated_reply}
          PROMPT
        }
      ],
      posthog_user_id: inbox.account.id
    )

    content = response["choices"][0]["message"]["content"].to_s.downcase

    content != "no"
  end

  # Delete all messages, and readd them back.
  def debug_refresh
    account = inbox.account
    user_id = "me"

    account.with_gmail_service do |service|
      thread_response = service.get_user_thread(user_id, thread_id)

      ActiveRecord::Base.transaction do
        messages.destroy_all

        Topic.cache_from_gmail(inbox, thread_response)
      end
    end
  end

  def should_auto_dismiss?
    last_message_str = messages.last.to_s_anon

    response = OpenRouterClient.chat(
      models: [ "openai/gpt-5:nitro" ],
      messages: [
        {
          role: "system",
           content: "Is this email NOT a customer support email? Should it be automatically dismissed from the customer support queue? Only reply with 'yes' or 'no.'"
        },
        {
          role: "user",
          content: last_message_str
        }
      ],
      posthog_user_id: inbox.account.id
    )

    response["choices"][0]["message"]["content"].downcase == "yes"
  end

  def move_to_no_action_required!
    self.status = :no_action_required_marked_by_user
    save!
  end

  def move_to_requires_action!
    self.status = :requires_action_human_needed
    save!
  end

  def user_replied_last?
    from_email == inbox.account.email
  end

  def is_old_email?
    date < OLD_EMAIL_DAYS_THRESHOLD.days.ago
  end

  def awaiting_customer?
    from_email == inbox.account.email
  end

  def send_reply!(reply_text)
    most_recent_message = messages.order(date: :desc).first
    raise "Cannot send email: No messages found in this topic." if most_recent_message.nil?

    inbox.account.deliver_reply(self, reply_text)

    # Label the message that was replied to (not the new outbound message)
    # so templates can be associated with the customer's original question
    most_recent_message.message_embedding.label_as_used_by_templates(templates)

    update(generated_reply: "", templates: [])
  end

  def self.cache_from_gmail(inbox, gmail_api_thread)
    thread_id = gmail_api_thread.id
    Topic.with_advisory_lock("inbox:#{inbox.id}:thread_id:#{thread_id}") do
      ActiveRecord::Base.transaction do
        topic = inbox.topics.find_or_initialize_by(thread_id: thread_id)

        api_messages = gmail_api_thread.messages
        cached_messages = api_messages.map do |api_message|
          Message.cache_from_gmail(topic, api_message)
        end

        first_message = cached_messages.first
        last_message = cached_messages.last

        date = last_message.date
        subject = first_message.subject
        from_email = last_message.from_email
        from_name = last_message.from_name
        to_email = last_message.to_email
        to_name = last_message.to_name
        message_count = gmail_api_thread.messages.count
        snippet = last_message.snippet

        topic.assign_attributes(
          snippet: snippet,
          date: date,
          subject: subject,
          from_email: from_email,
          from_name: from_name,
          to_email: to_email,
          to_name: to_name,
          message_count: message_count
        )

        # Method below need access to saved items
        topic.save!

         if topic.requires_action_ai_auto_replied?
           # Preserve auto-replied status when re-importing to avoid state reset
           # Keep the existing auto-replied status and don't re-process
           # YES THIS IS HUGE CODE SMELL.
           # i don't know how to fix but.
           # Preserve auto-replied status when re-importing to avoid state reset
         elsif topic.is_old_email?
           # During onboarding don't waste time with emails older than 3 days
           topic.status = :no_action_required_is_old_email
           topic.generated_reply = ""
         elsif topic.user_replied_last?
           topic.status = :no_action_required_awaiting_customer
           topic.generated_reply = ""
         elsif topic.should_auto_dismiss?
           topic.status = :no_action_required_marked_by_ai
           topic.generated_reply = ""
         else
           topic.status = :requires_action_human_needed
           topic.auto_select_templates
           topic.generate_reply
           topic.auto_reply_if_safe
         end

        topic.save!
      end
    end
  end

  private

  def associate_templates_with_message_embedding(templates, message_embedding)
    templates.each do |template|
      next if template.message_embeddings.include?(message_embedding)

      template.message_embeddings << message_embedding
    end
  end

  def broadcast_inbox_refresh
    return unless inbox_id

    Turbo::StreamsChannel.broadcast_refresh_to([ :inbox, inbox_id ])
  end
end
