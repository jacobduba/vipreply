# frozen_string_literal: true

class Topic < ApplicationRecord
  belongs_to :inbox
  has_many :template_topics, dependent: :destroy
  has_many :templates, through: :template_topics

  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages

  enum :status, %i[needs_reply has_reply]

  scope :not_spam, -> { where(is_spam: false) }

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

  # during merge rename: autoselect_templates
  def find_best_templates
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

    candidate_template_sets_ids = Sync do
      candidate_template_set = message_embeddings.map do |message_embedding|
        Async do
          past_message = message_embedding.message.to_s_anon

          chat = Faraday.new(url: "https://openrouter.ai/api/v1") do |f|
            f.request :retry, {
              max: 5,
              interval: 1,
              backoff_factor: 2,
              retry_statuses: [ 408, 429, 500, 502, 503, 504, 508 ],
              methods: %i[post]
            }
            f.request :authorization, "Bearer", Rails.application.credentials.openrouter_api_key
            f.request :json
            f.response :json
          end.post("chat/completions", {
            model: "openai/gpt-5:nitro",
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
            ]
          })

          same_cards_required = chat.body["choices"][0]["message"]["content"].downcase == "yes"

          if same_cards_required
            message_embedding.templates.map(&:id) # turn template model into its id -> later we need uniq to work and uniq doesnt work with lists of active record models
          end
        end
      end

      candidate_template_set.map(&:wait)
    end

    # finds unique sets of candidate templates (which are lists of ids of templates)
    candidate_template_sets_ids_uniq = candidate_template_sets_ids
      .compact # if the candidate example is nil, that means LLM determined that candidate wasn't the same
      .uniq # make sure the lists of candidate templates are uniq

    # TODO ::: REMOVE THIS IS IS SHIT
    # IF SOMEONE HAS A DUPLICATE TEMPLATE>>> I MEAN HWO WOU
    # okay so if theres MORE THAN 1 unique set of candidate examples...
    # STOP
    return unless candidate_template_sets_ids_uniq.length == 1
    # there should only be one set of candidate templates worth auto selecting for one type of email
    # if more than one, the user should manually select the templates

    chosen_templates_set_ids = candidate_template_sets_ids_uniq.first
    # Clear existing templates and add new ones
    template_topics.destroy_all
    chosen_templates_set_ids.each do |template_id|
      template_topics.create!(template_id: template_id)
    end
  end

  # during merge: list_templates_by_similiarity
  def list_templates_by_relevance
    latest_message = messages.order(date: :desc).first
    # List all templates when no embedding
    # This is the case for messages loaded before templates v2
    # Could probaly remove this in a month or two
    return inbox.templates unless latest_message&.message_embedding&.embedding

    target_embedding = latest_message.message_embedding.embedding
    target_embedding_literal = ActiveRecord::Base.connection.quote(target_embedding.to_s)

    # we're using cosine distance

    # inbox.templates
    #   .left_joins(:message_embeddings)
    #   .select(<<~SQL)
    #     templates.id AS id,
    #     templates.output AS output,
    #     MAX(1 - ((message_embeddings.embedding <=> #{target_embedding_literal}::vector) / 2)) AS similarity
    #   SQL
    #   .group("templates.id, templates.output")
    #   .order("similarity DESC NULLS LAST")
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

  def attached_templates_plus_email
    latest_message = messages.order(date: :desc).first

    template_prompt = templates.map.with_index { |t, i| "Smart template ##{i + 1}:\n#{t.output}" }.join("\n\n")

    <<~PROMPT
      SMART TEMPLATES:
      #{template_prompt}
      EMAIL:
      #{latest_message}
    PROMPT
  end

  def generate_reply
    llm_res = Faraday.new(url: "https://openrouter.ai/api/v1") do |f|
      f.request :retry, {
        max: 5,
        interval: 1,
        backoff_factor: 2,
        retry_statuses: [ 408, 429, 500, 502, 503, 504, 508 ],
        methods: %i[post]
      }
      f.request :authorization, "Bearer", Rails.application.credentials.openrouter_api_key
      f.request :json
      f.response :json
    end.post("chat/completions", {
      model: "cohere/command-a:nitro",
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are an AI agent answering customer support emails for a business.
            Your goal is to provide helpful responses to customer inquiries.
            CRITICAL: Do NOT make up, invent, or fabricate any information. Only use facts explicitly stated in the provided smart templates. If something is not directly mentioned in the smart templates, do not include it.
            If the template contains a link, make sure you provide a link or hyperlink to the customer.
            Do not include any email signature, closing salutation, or sign-off at the end of the email. End the email with the main content only.
            Always start your response with a greeting followed by the customer's name.
            Use a friendly and active voice.
            Write as if you're personally typing this email to a friend - use your own natural language, vary sentence structure, and avoid any phrases that sound like they came from a script.
            Treat the customer as an equal: do not praise or cristice them.
            You may want to thank them for reaching out or asking another question. Ask if they have any more questions at the end.
          PROMPT
        },
        {
          role: "user",
          content: attached_templates_plus_email
        }
      ]
    })

    # Log to see how many tokens users are using
    prompt_tokens = llm_res.body["usage"]["prompt_tokens"]
    completion_tokens = llm_res.body["usage"]["completion_tokens"]

    account = inbox.account
    account.increment!(:input_token_usage, prompt_tokens)
    account.increment!(:output_token_usage, completion_tokens)

    self.generated_reply = llm_res.body["choices"][0]["message"]["content"].strip.tr("—", " - ")
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

  def detect_autosend
    return unless templates.any?

    chat = Faraday.new(url: "https://openrouter.ai/api/v1") do |f|
      f.request :retry, {
        max: 5,
        interval: 1,
        backoff_factor: 2,
        retry_statuses: [ 408, 429, 500, 502, 503, 504, 508 ],
        methods: %i[post]
      }
      f.request :authorization, "Bearer", Rails.application.credentials.openrouter_api_key
      f.request :json
      f.response :json
    end.post("chat/completions", {
      model: "openai/gpt-5:nitro",
      messages: [
        {
          role: "system",
          content: "Do you have enough information from the smart templates to answer the customer email? Only reply with 'yes' or 'no.'"
        },
        {
          role: "user",
          content: attached_templates_plus_email
        }
      ]
    })

    self.will_autosend = chat.body["choices"][0]["message"]["content"].downcase == "yes"
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
        is_old_email = date < 3.days.ago
        status = if from_email == inbox.account.email
          :has_reply
        elsif is_old_email
          :has_reply
        else
          :needs_reply
        end
        message_count = gmail_api_thread.messages.count
        awaiting_customer = (from_email == inbox.account.email)
        snippet = last_message.snippet

        topic.assign_attributes(
          snippet: snippet,
          date: date,
          subject: subject,
          from_email: from_email,
          from_name: from_name,
          to_email: to_email,
          to_name: to_name,
          status: status,
          awaiting_customer: awaiting_customer,
          message_count: message_count
        )

        # Method below need access to saved items
        topic.save!

        if topic.has_reply? || is_old_email
          topic.will_autosend = false
          topic.generated_reply = ""
        else
          topic.find_best_templates
          topic.generate_reply
          topic.detect_autosend
        end

        topic.save!
      end
    end
  end

  private
end
