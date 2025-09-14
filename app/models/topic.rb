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

    candidate_templates = list_templates_by_relevance

    selected_candidates = candidate_templates.take_while do |candidate|
      chat = Faraday.new(url: "https://openrouter.ai/api/v1") do |f|
        f.request :retry, {
          max: 5,
          interval: 1,
          backoff_factor: 2,
          retry_statuses: [408, 429, 500, 502, 503, 504, 508],
          methods: %i[post]
        }
        f.request :authorization, "Bearer", Rails.application.credentials.openrouter_api_key
        f.response :json, content_type: "application/json"
      end.post("chat/completions") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          model: "openai/gpt-oss-120b:nitro",
          messages: [
            {
              role: "system",
              content: "Does the smart template help answer the email? Only reply 'yes' or 'no.'"
            },
            {
              role: "user",
              content: <<~PROMPT
                Smart template:
                #{candidate.output}
                Email:
                #{latest_message}
              PROMPT
            }
          ]
        }.to_json
      end

      chat.body["choices"][0]["message"]["content"].downcase == "yes"
    end

    # Automatically attach templates to the topic with confidence scores
    if selected_candidates.any?
      # Clear existing templates and add new ones with confidence scores
      template_topics.destroy_all
      selected_candidates.each do |candidate|
        template_topics.create!(
          template_id: candidate.id,
          confidence_score: candidate.similarity.to_f
        )
      end
    end

    nil
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
        MAX(GREATEST(1 - ((message_embeddings.embedding <=> #{target_embedding_literal}::vector)), 0)) AS similarity
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
    return inbox.templates unless latest_message&.message_embedding&.embedding

    target_embedding = latest_message.message_embedding.embedding
    target_embedding_literal = ActiveRecord::Base.connection.quote(target_embedding.to_s)

    Message
      .joins(message_embedding: :templates)
      .where(templates: {id: template_id})
      .select("messages.*, (message_embeddings.embedding <=> #{target_embedding_literal}::vector) AS distance")
      .order("distance")
      .first
  end

  def generate_reply
    latest_message = messages.order(date: :desc).first
    message_text = latest_message.to_s

    template_prompt = templates.map.with_index { |t, i| "SMART TEMPLATE ##{i + 1}:\n#{t.output}" }.join("\n\n") + "\n\n"

    email_prompt = "EMAIL:\n#{message_text}\nRESPONSE:\n"
    prompt = "#{template_prompt}#{email_prompt}"
    reply = fetch_generation(prompt)
    self.generated_reply = reply
  end

  # Delete all messages, and readd them back.
  def debug_refresh
    account = inbox.account
    user_id = "me"

    account.with_gmail_service do |service|
      thread_response = service.get_user_thread(user_id, thread_id)

      ActiveRecord::Base.transaction do
        messages.destroy_all

        Topic.cache_from_gmail(thread_response, snippet, inbox)
      end
    end
  end

  def self.cache_from_gmail(response_body, inbox)
    ActiveRecord::Base.transaction do
      thread_id = response_body.id
      topic = inbox.topics.find_or_initialize_by(thread_id: thread_id)
      topic.save!

      api_messages = response_body.messages
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
      message_count = response_body.messages.count
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

      unless topic.has_reply? || is_old_email
        topic.find_best_templates
        topic.generate_reply
      end

      topic.save!
    end
  end

  private

  def fetch_generation(prompt)
    groq_api_key = Rails.application.credentials.groq_api_key
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {
      "Authorization" => "Bearer #{groq_api_key}",
      "Content-Type" => "application/json"
    }

    system_prompt = <<~PROMPT
      You are a compassionate, empathetic, and professional person answering customer support emails for a small business.
      Your goal is to provide helpful responses to customer inquiries.

      CRITICAL: You MUST incorporate information from ALL provided smart templates in your response, even if they weren't directly asked about.

      Do NOT make up, invent, or fabricate any information. Only use facts explicitly stated in the provided smart templates. If something is not directly mentioned, do not include it.
      If the template contains a link, make sure you provide a link or hyperlink to the customer.
      Do not include any email signature, closing salutation, or sign-off at the end of the email. End the email with the main content only.
      Always start your response with a greeting followed by the customer's name.
      Use a friendly and active voice. You may want to thank them for reaching out.
      Avoid "I just wanted to let you know" or "I see you are asking about."
      Write as if you're personally typing this email to a friend - use your own natural language, vary sentence structure, and avoid any phrases that sound like they came from a script.
    PROMPT

    data = {
      model: "moonshotai/kimi-k2-instruct-0905",
      messages: [
        {
          role: "system",
          content: system_prompt
        },
        {
          role: "user",
          content: prompt
        }
      ]
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers)
    parsed = JSON.parse(response.tap(&:value).body)

    # Log to see how many tokens users are using
    account = inbox.account
    account.increment!(:input_token_usage, parsed["usage"]["prompt_tokens"])
    account.increment!(:output_token_usage, parsed["usage"]["completion_tokens"])

    generated_text = parsed["choices"][0]["message"]["content"]
    generated_text.strip
    generated_text.tr("—", " - ")
  end
end
