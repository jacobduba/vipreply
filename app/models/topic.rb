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

    template_prompt = if template_attached?
      <<~PROMPT
        Template response email:
        #{template.output}
      PROMPT
    else
      ""
    end
    email_prompt = <<~PROMPT
      Email:
      #{message}
      Response:
    PROMPT
    prompt = "#{template_prompt}#{email_prompt}"
    reply = fetch_generation(prompt)

    self.generated_reply = reply
  end

  private

  def fetch_generation(prompt)
    openai_api_key = Rails.application.credentials.openai_api_key

    url = "https://api.openai.com/v1/chat/completions"
    headers = {
      "Authorization" => "Bearer #{openai_api_key}",
      "Content-Type" => "application/json"
    }
    data = {
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are a Customer Support Representative who answers emails.
            Be compassionate: emphasize with the customer.
            Include a salutation such as Hello or Greetings.
            DO NOT include a closing, such as Best regards or Kind regards.
            Don't waste the customers time.
            You will be given a template containing a template response email.
            Then you will given an email and you must generate a response for it using the template.
          PROMPT
        },
        {
          role: "user",
          content: prompt
        }
      ]
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    generated_text = JSON.parse(response.body)["choices"][0]["message"]["content"]
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
