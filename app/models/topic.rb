class Topic < ApplicationRecord
  belongs_to :inbox
  belongs_to :template, optional: true

  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages

  enum :template_status, [:no_templates_exist_at_generation, :template_removed, :template_attached, :skipped_no_reply_needed]

  def generate_reply
    message = messages.order(date: :desc).first # Newest message
    message_str = message.to_s

    neighbor = Template.find_similar(message_str)

    example_prompt = if neighbor
      <<~HEREDOC
        Example recieved email:
        #{neighbor.input}
        Example response email:
        #{neighbor.output}
      HEREDOC
    else
      ""
    end

    email_for_prompt = <<~HEREDOC
      Email:
      #{message}
      Response:
    HEREDOC

    prompt = "#{example_prompt}#{email_for_prompt}"

    reply = fetch_generation(prompt)
    template_status = neighbor ? :template_attached : :no_templates_exist_at_generation

    self.generated_reply = reply
    self.template = neighbor
    self.template_status = template_status
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
          content: <<~HEREDOC
            You are a Customer Support Representative who answers emails.
            You will be given a template containing a example received email and an example response email.
            Then you will given an email and you must generate a response for it using the template.
            Write it in your own words!
            Be compassionate: emphasize with the customer.
            Include a salutation such as Hello or Greetings.
            DO NOT include a closing, such as Best regards or Kind regards."
          HEREDOC
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

    all_taken_care_of = from == inbox.account.email
    message_count = response_body.messages.count

    # Find or create topic
    topic = inbox.topics.find_or_initialize_by(thread_id: thread_id)
    topic.assign_attributes(
      snippet: snippet,
      date: date,
      subject: subject,
      from: from,
      to: to,
      all_taken_care_of: all_taken_care_of,
      message_count: message_count
    )

    topic.save! if topic.new_record?

    # Cache messages
    messages.each { |message| Message.cache_from_gmail(topic, message) }

    if all_taken_care_of
      topic.template_status = :skipped_no_reply_needed
    else
      topic.generate_reply
    end

    topic.save!
  end
end
