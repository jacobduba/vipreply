require "google/apis/gmail_v1"

class UpdateFromHistoryJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find(inbox_id)
    account = inbox.account
    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = account.google_credentials

    user_id = "me"
    history_id = inbox.history_id

    Rails.logger.info "Updating inbox from history_id: #{history_id} for inbox #{inbox.id}"

    begin
      # Fetch history since the last `history_id`
      history_response = gmail_service.list_user_histories(
        user_id,
        start_history_id: history_id,
        history_types: ["messageAdded"]
      )

      if history_response.history.present?
        history_response.history.each do |history|
          history.messages_added&.each do |message_meta|
            next if message_meta.message.label_ids&.include?("DRAFT")

            thread_id = message_meta.message.thread_id

            # Fetch the entire thread from Gmail
            thread_response = gmail_service.get_user_thread(user_id, thread_id)

            # Recreate the thread and its messages
            cache_topic(thread_response, thread_response.messages.last.snippet, inbox)
          end
        end
      else
        Rails.logger.info "No new history changes for inbox #{inbox.id}."
      end

      # Update the latest history_id
      if history_response.history_id
        inbox.update!(history_id: history_response.history_id.to_i)
      end
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Failed to update inbox from history: #{e.message}"
    end
  end

  def cache_topic(response_body, snippet, inbox)
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

    if topic.changed?
      topic.save!
      Rails.logger.info "Updated topic: #{topic.id}"
    else
      Rails.logger.info "No changes for topic: #{topic.id}"
    end

    # Cache messages
    messages.each { |message| cache_message(topic, message) }

    if all_taken_care_of
      topic.update!(template_status: :skipped_no_reply_needed)
    else
      gen_reply(topic, inbox)
    end
  end

  # Returns Message
  def cache_message(topic, message)
    headers = message.payload.headers
    message_id = message.id
    date = DateTime.parse(headers.find { |h| h.name.downcase == "date" }.value)
    subject = headers.find { |h| h.name.downcase == "subject" }.value
    from = headers.find { |h| h.name.downcase == "from" }.value
    to = headers.find { |h| h.name.downcase == "to" }.value
    internal_date = Time.at(message.internal_date / 1000).to_datetime
    snippet = message.snippet

    collected_parts = extract_parts(message.payload)

    plaintext = collected_parts[:plain]
    html = collected_parts[:html]
    attachments = collected_parts[:attachments]

    # Find or create message
    msg = topic.messages.find_or_initialize_by(message_id: message_id)
    msg.assign_attributes(
      date: date,
      subject: subject,
      from: from,
      to: to,
      internal_date: internal_date,
      plaintext: plaintext,
      html: html,
      snippet: snippet
    )

    if msg.changed?
      msg.save!
      Rails.logger.info "Saved message: #{msg.id}"
    else
      Rails.logger.info "No changes for message: #{msg.id}"
    end

    # Save or update attachments
    attachments.each do |attachment|
      existing_attachment = msg.attachments.find_or_initialize_by(attachment_id: attachment[:attachment_id])
      existing_attachment.assign_attributes(
        content_id: attachment[:content_id],
        filename: attachment[:filename],
        mime_type: attachment[:mime_type],
        size: attachment[:size]
      )

      if existing_attachment.changed?
        existing_attachment.save!
        Rails.logger.info "Saved attachment: #{existing_attachment.id}"
      else
        Rails.logger.info "No changes for attachment: #{existing_attachment.id}"
      end
    end

    msg
  end

  def extract_parts(part)
    result = {
      plain: nil,
      html: nil,
      attachments: []
    }

    if part.mime_type.start_with?("multipart/")
      part.parts.each do |subpart|
        subresult = extract_parts(subpart)
        result[:plain] ||= subresult[:plain]
        result[:html] ||= subresult[:html]
        result[:attachments].concat(subresult[:attachments])
      end
    elsif part.mime_type == "text/plain"
      result[:plain] = part.body.data
    elsif part.mime_type == "text/html"
      result[:html] = part.body.data
    else
      content_disposition = part.headers.find { |h| h.name == "Content-Disposition" }&.value
      if content_disposition&.start_with?("attachment") || part.filename
        cid_header = part.headers.find { |h| h.name == "Content-ID" }&.value
        x_attachment_id = part.headers.find { |h| h.name == "X-Attachment-Id" }&.value
        cid = if x_attachment_id
          "cid:#{x_attachment_id}"
        elsif cid_header
          "cid:#{cid_header[1..-2]}"
        end
        result[:attachments] << {
          attachment_id: part.body.attachment_id,
          content_id: cid,
          filename: part.filename,
          mime_type: part.mime_type,
          size: (part.body.size / 1024.0).round
        }
      end
    end
    result
  end

  def fetch_embedding(input)
    openai_api_key = Rails.application.credentials.openai_api_key

    url = "https://api.openai.com/v1/embeddings"
    headers = {
      "Authorization" => "Bearer #{openai_api_key}",
      "Content-Type" => "application/json"
    }
    data = {
      input: input,
      model: "text-embedding-3-large"
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    JSON.parse(response.body)["data"][0]["embedding"]
  end

  def gen_reply(topic, inbox)
    message = topic.messages.order(date: :desc).first # Newest message
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

    topic.update!(generated_reply: reply, template: neighbor, template_status: template_status) # Cache result in DB

    {
      email: message_str,
      reply: reply,
      template: neighbor
    }
  end

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
end
