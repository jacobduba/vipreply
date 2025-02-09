class Topic < ApplicationRecord
  belongs_to :inbox
  belongs_to :template, optional: true

  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages

  enum :status, [:needs_reply, :has_reply]
  enum :template_status, [
    :could_not_find_template,
    :template_removed,
    :template_attached,
    :skipped_no_reply_needed
  ]

  EMBEDDING_TOKEN_LIMIT = 8191

  def find_best_template
    message = messages.order(date: :desc).first # Newest message
    best_template = Example.find_best_template(message, inbox)

    self.template = best_template
    self.template_status = if best_template
      :template_attached
    else
      :could_not_find_template
    end
  end

  scope :not_spam, -> { where(is_spam: false) }

  def generate_reply
    message = messages.order(date: :desc).first # Newest message

    message = truncate_text(message.to_s, EMBEDDING_TOKEN_LIMIT)

    template_prompt = if template_attached?
      <<~PROMPT
        TEMPLATE RESPONSE EMAIL:
        #{template.output}\n\n
      PROMPT
    else
      ""
    end
    email_prompt = <<~PROMPT
      EMAIL:
      #{message}
      RESPONSE:
    PROMPT
    prompt = "#{template_prompt}#{email_prompt}"
    reply = fetch_generation(prompt)

    self.generated_reply = reply
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

    system_prompt = <<~PROMPT
      You are a compassionate and empathetic business owner receiving customer support emails for a small business.
      Greet the customer briefly and support them with their questions based on an accompanying template. 
      Keep replies short as to not waste the customers time. 
      DO NOT include any farewell phrases or closing salutations.
    PROMPT

    data = {
      model: "claude-3-5-sonnet-20241022",
      max_tokens: 2048,
      system: system_prompt,
      messages: [
        {role: "user", content: prompt}
      ]
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    parsed = JSON.parse(response.body)
    generated_text = parsed["content"].map { |block| block["text"] }.join(" ")
    generated_text.strip
  end

  def self.cache_from_gmail(response_body, snippet, inbox)
    thread_id = response_body.id
    first_message = response_body.messages.first
    first_message_headers = first_message.payload.headers
    last_message = response_body.messages.last
    last_message_headers = last_message.payload.headers
    messages = response_body.messages

    # Extract relevant fields
    date = DateTime.parse(last_message_headers.find { |h| h.name.downcase == "date" }.value)
    subject = first_message_headers.find { |h| h.name.downcase == "subject" }.value
    from_header = last_message_headers.find { |h| h.name.downcase == "from" }.value
    from = from_header.include?("<") ? from_header[/<([^>]+)>/, 1] : from_header
    to_header = last_message_headers.find { |h| h.name.downcase == "to" }.value
    to = to_header.include?("<") ? to_header[/<([^>]+)>/, 1] : to_header

    status = if from == inbox.account.email
      :has_reply
    else
      :needs_reply
    end
    awaiting_customer = from == inbox.account.email
    message_count = response_body.messages.count

    # Find or create topic
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

    # Cache messages
    messages.each { |message| Message.cache_from_gmail(topic, message) }

    if topic.has_reply?
      topic.template_status = :skipped_no_reply_needed
    else
      topic.find_best_template
      topic.generate_reply
    end

    topic.save!
  end
end
