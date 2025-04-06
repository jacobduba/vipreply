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

  def find_best_templates
    latest_message = messages.order(date: :desc).first
    return Template.none unless latest_message&.message_embedding&.vector

    base_threshold = 0.67
    secondary_threshold = 0.71
    margin = 0.07

    target_embedding = latest_message.message_embedding
    return Template.none unless target_embedding

    target_vector = target_embedding.vector
    target_vector_literal = ActiveRecord::Base.connection.quote(target_vector.to_s)

    # Changed from inbox.templates to inbox.account.templates
    candidate_templates = inbox.account.templates
      .joins(:message_embeddings)
      .select(<<~SQL)
        templates.id AS template_id,
        templates.output AS template_text,
        MAX(-1 * (message_embeddings.vector <#> #{target_vector_literal}::vector)) AS similarity
      SQL
      .group("templates.id, templates.output")
      .order("similarity DESC")

    # Print candidate templates for debugging
    puts("Candidate Templates:")
    candidate_templates.each do |candidate|
      puts("Template ID: #{candidate.template_id}, Similarity: #{candidate.similarity}")
      puts("Template Text: #{candidate.template_text}")
    end

    selected_candidates = []
    if candidate_templates.any? && candidate_templates.first.similarity.to_f >= base_threshold
      top_similarity = candidate_templates.first.similarity.to_f
      selected_candidates << candidate_templates.first

      candidate_templates[1..-1].each do |candidate|
        sim = candidate.similarity.to_f
        if sim >= secondary_threshold && (top_similarity - sim) <= margin
          selected_candidates << candidate
        end
      end
    end

    selected_templates = Template.where(id: selected_candidates.map(&:template_id))

    # Automatically attach templates to the topic
    if selected_templates.any?
      self.templates = selected_templates
      save!
      Rails.logger.info "Attached #{selected_templates.count} templates to topic #{id}"
    else
      Rails.logger.info "Could not find matching templates for topic #{id}"
    end

    selected_templates
  end

  def list_templates_by_relevance
    latest_message = messages.order(date: :desc).first
    return Template.none unless latest_message&.message_embedding&.vector

    target_embedding = latest_message.message_embedding
    return Template.none unless target_embedding

    target_vector = target_embedding.vector
    target_vector_literal = ActiveRecord::Base.connection.quote(target_vector.to_s)

    inbox.account.templates
      .left_joins(:message_embeddings)
      .select(<<~SQL)
        templates.id AS id,
        templates.output AS output,
        MAX(-1 * (message_embeddings.vector <#> #{target_vector_literal}::vector)) AS similarity
      SQL
      .group("templates.id, templates.output")
      .order("similarity DESC NULLS LAST")
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
        {role: "user", content: prompt}
      ]
    }

    puts("Fetching generation from Anthropic API")
    puts("Prompt: #{prompt}")

    response = Net::HTTP.post(URI(url), data.to_json, headers)
    parsed = JSON.parse(response.tap(&:value).body)
    generated_text = parsed["content"].map { |block| block["text"] }.join(" ")
    generated_text.strip
  end

  def self.cache_from_provider(response_body, inbox)
    case inbox.provider
    when "google_oauth2"
      cache_from_gmail(response_body, response_body.messages.last.snippet, inbox)
    when "microsoft_office365"
      cache_from_outlook(response_body, inbox)
    else
      raise "Unknown provider: #{inbox.provider}"
    end
  end

  # Update the cache_from_outlook method in the Topic model

  def self.cache_from_outlook(conversation, inbox)
    thread_id = conversation["id"]

    # Make sure we have messages to work with
    return nil if conversation["messages"].blank?

    # Use the first message for thread metadata and last for date ordering
    first_message = conversation["messages"].first
    last_message = conversation["messages"].last

    date = DateTime.parse(last_message["receivedDateTime"])
    subject = first_message["subject"]

    # Get sender information
    from = if last_message["from"].present? && last_message["from"]["emailAddress"].present?
      last_message["from"]["emailAddress"]["address"]
    else
      "unknown@example.com"
    end

    # Get recipient information
    to = if last_message["toRecipients"].present? && last_message["toRecipients"].first.present?
      last_message["toRecipients"].first["emailAddress"]["address"]
    else
      "unknown@example.com"
    end

    snippet = last_message["bodyPreview"] || ""

    # Determine if email is old (more than 3 weeks)
    is_old_email = date < 3.weeks.ago

    # Determine message status based on sender and date
    # Check if the sender email matches any of the account's emails
    status = if inbox.account.owns_email?(from)
      :has_reply
    elsif is_old_email
      :has_reply
    else
      :needs_reply
    end

    # Determine if we're awaiting a customer response
    awaiting_customer = inbox.account.owns_email?(from)

    # Message count is simply the number of messages in the conversation
    message_count = conversation["messages"].count

    # Try to find an existing topic or create a new one
    topic = inbox.topics.find_or_initialize_by(thread_id: thread_id)

    topic.assign_attributes(
      snippet: snippet,
      last_message: date,
      last_updated: date,
      subject: subject,
      from: from,
      to: to,
      status: status,
      awaiting_customer: awaiting_customer,
      message_count: message_count
    )

    topic.save!
    Rails.logger.info "Saved topic: #{topic.id} '#{topic.subject}' (#{topic.message_count} messages)"

    # Process all messages in the conversation
    conversation["messages"].each do |message_data|
      Message.cache_from_outlook(topic, message_data)
    rescue => e
      Rails.logger.error "Error processing message for topic #{topic.id}: #{e.message}"
    end

    # Generate reply if needed
    unless topic.has_reply? || is_old_email
      topic.find_best_templates
      topic.generate_reply
    end

    topic.save!
    topic
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
    subject = subject_header ? subject_header.value : "(No Subject)"
    
    # Safely get from
    from_header_obj = last_message_headers.find { |h| h.name.downcase == "from" }
    from_header = from_header_obj ? from_header_obj.value : "unknown@example.com"
    from = from_header.include?("<") ? from_header[/<([^>]+)>/, 1] : from_header
    
    # Safely get to - this is where the error occurs
    to_header_obj = last_message_headers.find { |h| h.name.downcase == "to" }
    to_header = to_header_obj ? to_header_obj.value : "unknown@example.com"
    to = to_header.include?("<") ? to_header[/<([^>]+)>/, 1] : to_header
  
    is_old_email = date < 3.weeks.ago
  
    # Use the account.owns_email? method to check if the sender matches any of the account's emails
    status = if inbox.account.owns_email?(from)
      :has_reply
    elsif is_old_email
      :has_reply
    else
      :needs_reply
    end
  
    awaiting_customer = inbox.account.owns_email?(from)
    message_count = response_body.messages.count
  
    topic = inbox.topics.find_or_initialize_by(thread_id: thread_id)
    topic.assign_attributes(
      snippet: snippet,
      last_message: date,
      last_updated: date,
      subject: subject,
      from: from,
      to: to,
      status: status,
      awaiting_customer: awaiting_customer,
      message_count: message_count
    )
  
    topic.save!
  
    messages.each { |message| Message.cache_from_provider(topic, message) }
  
    unless topic.has_reply? || is_old_email
      topic.find_best_templates
      topic.generate_reply
    end
  
    topic.save!
    topic
  end
end
