# frozen_string_literal: true

class Topic < ApplicationRecord
  belongs_to :inbox
  has_and_belongs_to_many :templates

  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages

  enum :status, [:needs_reply, :has_reply]

  scope :not_spam, -> { where(is_spam: false) }

  # TODO: this is outdated
  EMBEDDING_TOKEN_LIMIT = 8191

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
    return Template.none unless latest_message&.message_embedding&.vector

    target_vector = latest_message.message_embedding.vector
    target_vector_literal = ActiveRecord::Base.connection.quote(target_vector.to_s)

    # Modified to only search templates with message_embeddings
    candidate_templates = inbox.templates
      .joins(:message_embeddings)
      .select(<<~SQL)
        templates.id AS template_id,
        templates.output AS template_text,
        MAX(-1 * (message_embeddings.vector <#> #{target_vector_literal}::vector)) AS similarity
      SQL
      .group("templates.id, templates.output")
      .order("similarity DESC NULLS LAST")

    first_threshold = 0.85
    additional_threshold = 0.9

    selected_candidates = []
    if candidate_templates.any? && candidate_templates.first.similarity.to_f >= first_threshold
      selected_candidates << candidate_templates.first

      candidate_templates[1..-1].each do |candidate|
        sim = candidate.similarity.to_f
        if sim >= additional_threshold
          selected_candidates << candidate
        end
      end
    end

    selected_templates = Template.where(id: selected_candidates.map(&:template_id))

    # Automatically attach templates to the topic
    if selected_templates.any?
      self.templates = selected_templates
      save!
    end

    selected_templates
  end

  # during merge: list_templates_by_similiarity
  def list_templates_by_relevance
    latest_message = messages.order(date: :desc).first
    # List all templates when no embedding
    # This is the case for messages loaded before templates v2
    # Could probaly remove this in a month or two
    return inbox.templates unless latest_message&.message_embedding&.vector

    target_vector = latest_message.message_embedding.vector
    target_vector_literal = ActiveRecord::Base.connection.quote(target_vector.to_s)

    inbox.templates
      .left_joins(:message_embeddings)
      .select(<<~SQL)
        templates.id AS id,
        templates.output AS output,
        MAX(-1 * (message_embeddings.vector <#> #{target_vector_literal}::vector)) AS similarity
      SQL
      .group("templates.id, templates.output")
      .order("similarity DESC NULLS LAST")
  end

  # Debugging helper to identify the message most similar to the latest message
  # that caused this template's similiarity score for the current topic.
  def debug_closest_message_for_template(template_id)
    latest_message = messages.order(date: :desc).first
    # List all templates when no embedding
    # This is the case for messages loaded before templates v2
    # Could probaly remove this in a month or two
    return inbox.templates unless latest_message&.message_embedding&.vector

    target_vector = latest_message.message_embedding.vector
    target_vector_literal = ActiveRecord::Base.connection.quote(target_vector.to_s)

    Message
      .joins(message_embedding: :templates)
      .where(templates: {id: template_id})
      .select("messages.*, (message_embeddings.vector <#> #{target_vector_literal}::vector) AS distance")
      .order("distance")
      .first
  end

  def generate_reply
    latest_message = messages.order(date: :desc).first
    # TODO: why do we need to truncate the last message with the embedding token limit?
    message_text = truncate_text(latest_message.to_s, EMBEDDING_TOKEN_LIMIT)

    template_prompt = if templates.any?
      "TEMPLATE RESPONSE EMAIL:\n" + templates.map(&:output).join("\n---\n") + "\n\n"
    else
      ""
    end

    email_prompt = "EMAIL:\n#{message_text}\nRESPONSE:\n"
    prompt = "#{template_prompt}#{email_prompt}"
    reply = fetch_generation(prompt)
    self.generated_reply = reply
  end

  # Delete all messages, and readd them back.
  def debug_refresh
    account = inbox.account
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = account.google_credentials
    user_id = "me"

    thread_response = gmail_service.get_user_thread(user_id, thread_id)

    ActiveRecord::Base.transaction do
      messages.destroy_all

      Topic.cache_from_gmail(thread_response, snippet, inbox)
    end
  end

  private

  # TODO: Make this more like MVC.
  # By that I mean, load emb
  def truncate_text(text, token_limit)
    encoding = TOKENIZER.encode(text)

    if encoding.tokens.size > token_limit
      truncated_ids = encoding.ids[0...token_limit]
      TOKENIZER.decode(truncated_ids)
    else
      text
    end
  end

  def fetch_generation(prompt)
    anthropic_api_key = Rails.application.credentials.anthropic_api_key
    url = "https://api.anthropic.com/v1/messages"
    headers = {
      "x-api-key" => anthropic_api_key,
      "anthropic-version" => "2023-06-01",
      "Content-Type" => "application/json"
    }

    # openai_api_key = Rails.application.credentials.openai_api_key
    # url = "https://api.openai.com/v1/chat/completions"
    # headers = {
    #   "Authorization" => "Bearer #{openai_api_key}",
    #   "Content-Type" => "application/json"
    # }

    system_prompt = <<~PROMPT
      You are a compassionate and empathetic business owner receiving customer support emails for a small business.

      Your goal is to provide helpful and concise responses to customer inquiries.
      Use the customer's name from their email signature; if it's missing, use the 'From' header. Otherwise DO NOT use the 'From' header name.
      If the template contains a link, make sure you provide a link or hyperlink to the customer.
      DO NOT include a sign-off.
    PROMPT

    data = {
      # model: "claude-3-5-sonnet-20241022",
      # model: "claude-3-7-sonnet-20250219",
      model: "claude-sonnet-4-20250514",
      max_tokens: 2048,
      system: system_prompt,
      messages: [
        {
          role: "user", content: prompt
        }
      ]
    }

    # data = {
    #   model: "gpt-4.5-preview-2025-02-27",
    #   max_tokens: 2048,
    #   messages: [
    #     {
    #       role: "developer",
    #       content: system_prompt
    #     },
    #     {
    #       role: "user",
    #       content: prompt
    #     }
    #   ]
    # }

    response = Net::HTTP.post(URI(url), data.to_json, headers)
    parsed = JSON.parse(response.tap(&:value).body)
    # Anthropic
    generated_text = parsed["content"].map { |block| block["text"] }.join(" ")
    # OpenAI
    # generated_text = parsed["choices"][0]["message"]["content"]
    generated_text.strip
  end

  def self.cache_from_gmail(response_body, snippet, inbox)
    ActiveRecord::Base.transaction do
      thread_id = response_body.id
      topic = inbox.topics.find_or_initialize_by(thread_id: thread_id)
      topic.save!

      api_messages = response_body.messages
      cached_messages = api_messages.map { |api_message|
        Message.cache_from_gmail(topic, api_message)
      }

      first_message = cached_messages.first
      last_message = cached_messages.last

      date = last_message.date
      subject = first_message.subject
      from_email = last_message.from_email
      from_name = last_message.from_name
      to_email = last_message.to_email
      to_name = last_message.to_name
      is_old_email = date < 3.weeks.ago
      status = if from_email == inbox.account.email
        :has_reply
      elsif is_old_email
        :has_reply
      else
        :needs_reply
      end
      message_count = response_body.messages.count
      awaiting_customer = (from_email == inbox.account.email)

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

      unless topic.has_reply? || is_old_email
        topic.find_best_templates
        topic.generate_reply
      end

      topic.save!
    end
  end
end
