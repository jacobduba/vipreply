class Topic < ApplicationRecord
  belongs_to :inbox
  has_and_belongs_to_many :templates

  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages

  enum :status, [:needs_reply, :has_reply]

  scope :not_spam, -> { where(is_spam: false) }

  EMBEDDING_TOKEN_LIMIT = 8191

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

    first_threshold = 0.7
    additional_threshold = 0.8

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

  def debug_refresh
    account = inbox.account
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = account.google_credentials
    user_id = "me"

    thread_response = gmail_service.get_user_thread(user_id, thread_id)

    ActiveRecord::Base.transaction do
      messages.destroy_all

      thread_response.messages.each do |message|
        Message.cache_from_gmail(self, message)
      end

      last_message = thread_response.messages.last
      last_message_headers = last_message.payload.headers

      update!(
        date: DateTime.parse(last_message_headers.find { |h| h.name.downcase == "date" }.value),
        snippet: thread_response.messages.last.snippet,
        message_count: thread_response.messages.count
      )
    end
  end

  private

  def tokenizer
    @tokenizer ||= Tokenizers::Tokenizer.from_pretrained("voyageai/voyage-3-large")
  end

  def truncate_text(text, token_limit)
    encoding = tokenizer.encode(text)

    if encoding.tokens.size > token_limit
      truncated_ids = encoding.ids[0...token_limit]
      tokenizer.decode(truncated_ids)
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

      Your goal is to provide helpful and very concise responses to customer inquiries, using the provided templates as a guide.
      Greet the customer briefly and answer their questions based using the accompanying templates.
      Use the customer's name from their email signature; if it's missing, use the 'From' header. Otherwise DO NOT use the 'From' header name.
      Always use ALL of the provided templates.
      Never mention 'template'. In a scenario where you can't answer a customer question just say you'll look into it.
      If the template contains a link, make sure you provide a link or hyperlink to the customer.
      DO NOT include any farewell phrases or closing salutations. DO NOT include a signature.
      DO NOT ASK if you have any other questions.
    PROMPT

    data = {
      # model: "claude-3-5-sonnet-20241022",
      model: "claude-3-7-sonnet-20250219",
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
    thread_id = response_body.id
    first_message = response_body.messages.first
    first_message_headers = first_message.payload.headers
    last_message = response_body.messages.last
    last_message_headers = last_message.payload.headers
    messages = response_body.messages

    # Safely get date
    date_header = last_message_headers.find { |h| h.name.downcase == "date" }
    date = date_header ? DateTime.parse(date_header.value) : DateTime.now

    # Safely get subject
    subject_header = first_message_headers.find { |h| h.name.downcase == "subject" }
    subject = subject_header&.value : "(No Subject)"

    # Safely get from
    from_header_obj = last_message_headers.find { |h| h.name.downcase == "from" }

    from_header = from_header_obj ? from_header_obj.value : "unknown@example.com"
    from = from_header.include?("<") ? from_header[/<([^>]+)>/, 1] : from_header

    # Safely get to - this is where the error occurs
    to_header_obj = last_message_headers.find { |h| h.name.downcase == "to" }

    to_header = to_header_obj ? to_header_obj.value : "unknown@example.com"
    to = to_header.include?("<") ? to_header[/<([^>]+)>/, 1] : to_header

    from = from_header.include?("<") ? from_header[/<([^>]+)>/, 1] : from_header
    to_header = last_message_headers.find { |h| h.name.downcase == "to" }.value
    to = to_header.include?("<") ? to_header[/<([^>]+)>/, 1] : to_header

    is_old_email = date < 3.weeks.ago

    status = if from == inbox.account.email
      :has_reply
    elsif is_old_email
      :has_reply
    else
      :needs_reply
    end

    awaiting_customer = (from == inbox.account.email)
    message_count = response_body.messages.count

    topic = inbox.topics.find_or_initialize_by(thread_id: thread_id)
    topic.assign_attributes(
      snippet: snippet,
      date: date,
      subject: subject,
      from: from,
      to: to,
      status: status,
      awaiting_customer: awaiting_customer,
      message_count: message_count
    )

    topic.save!

    messages.each { |message| Message.cache_from_gmail(topic, message) }

    unless topic.has_reply? || is_old_email
      topic.find_best_templates
      topic.generate_reply
    end

    topic.save!
  end
end
