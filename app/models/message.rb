class Message < ApplicationRecord
  # OpenAI lets us submit 8191 tokens... if the characters are under 8191
  # characters we can't go over 8191 tokens lol
  EMBEDDING_CHAR_LIMIT = 8191

  include ActionView::Helpers::TextHelper

  belongs_to :topic
  has_many :attachments, dependent: :destroy

  before_save :check_plaintext_nil

  def replace_cids_with_urls(host)
    return simple_format(plaintext) unless html

    updated_html = html.dup

    attachments.each do |attachment|
      next unless attachment.content_id

      attachment_url = attachment.url host

      updated_html.gsub!(attachment.content_id, attachment_url)
    end

    updated_html
  end

  def from
    if from_name
      "#{from_name} <#{from_email}>"
    else
      "#{from_email}"
    end
  end

  def to
    if to_name
      "#{to_name} <#{to_email}>"
    else
      "#{to_email}"
    end
  end

  # Stipe everything after "On .... wrote:"
  # Used for embedding vector
  def message_without_history
    return html unless plaintext
    lines = plaintext.lines

    cutoff_index = lines.find_index { |line|
      line.start_with?("On") && line.include?("wrote:")
    }

    plaintext.strip unless cutoff_index
    lines[0...cutoff_index].join.strip
  end

  def to_s
    <<~TEXT
      Date: #{date}
      From: #{from}
      To: #{to}
      Subject: #{subject}

      #{plaintext}
    TEXT
  end

  def generate_embedding
    embedding_text = <<~TEXT
      Subject: #{subject}
      Body:
      #{plaintext}
    TEXT

    fetch_embedding(embedding_text)
  end

  def self.parse_email_header(header)
    if header.include?("<")
      name = header.split("<").first.strip
      email = header[/<(.+?)>/, 1]
      [name, email]
    else
      [nil, header]
    end
  end

  # Returns Message
  def self.cache_from_gmail(topic, message)
    headers = message.payload.headers
    gmail_message_id = message.id
    date = DateTime.parse(headers.find { |h| h.name.downcase == "date" }.value)
    subject = headers.find { |h| h.name.downcase == "subject" }.value
    from_header = headers.find { |h| h.name.downcase == "from" }.value
    from_name, from_email = parse_email_header(from_header)
    to_header = headers.find { |h| h.name.downcase == "to" }.value
    to_name, to_email = parse_email_header(to_header)
    message_id = headers.find { |h| h.name.downcase == "message-id" }.value
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
      from_name: from_name,
      from_email: from_email,
      to_email: to_email,
      to_name: to_name,
      internal_date: internal_date,
      plaintext: plaintext,
      html: html,
      snippet: snippet,
      gmail_message_id: gmail_message_id
    )

    if msg.changed?
      msg.save!
      Rails.logger.info "Saved message: #{msg.id}"
    else
      Rails.logger.info "No changes for message: #{msg.id}"
    end

    # Attachment ids change whenever the topic is updated
    # https://stackoverflow.com/questions/28104157/how-can-i-find-the-definitive-attachmentid-for-an-attachment-retrieved-via-googl
    # My "solution" is to destory all the attachments and recreate them
    msg.attachments.destroy_all
    attachments.each do |attachment|
      Attachment.cache_from_gmail(msg, attachment)
    end

    msg
  end

  def self.extract_parts(part)
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
      content_disposition_header = part.headers.find { |h| h.name == "Content-Disposition" }&.value
      if content_disposition_header&.start_with?("attachment") || part.filename
        cid_header = part.headers.find { |h| h.name == "Content-ID" }&.value
        x_attachment_id = part.headers.find { |h| h.name == "X-Attachment-Id" }&.value
        cid = if x_attachment_id
          "cid:#{x_attachment_id}"
        elsif cid_header
          "cid:#{cid_header[1..-2]}"
        end
        content_disposition = content_disposition_header&.split(";")&.first&.strip
        result[:attachments] << {
          attachment_id: part.body.attachment_id,
          content_id: cid,
          filename: part.filename,
          mime_type: part.mime_type,
          size: (part.body.size / 1024.0).round,
          content_disposition: content_disposition
        }
      end
    end
    result
  end

  private

  def fetch_embedding(text)
    truncated_text = text.to_s.strip[0...EMBEDDING_CHAR_LIMIT]

    openai_api_key = Rails.application.credentials.openai_api_key

    url = "https://api.openai.com/v1/embeddings"
    headers = {
      "Authorization" => "Bearer #{openai_api_key}",
      "Content-Type" => "application/json"
    }
    data = {
      input: truncated_text,
      model: "text-embedding-3-large"
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    JSON.parse(response.body)["data"][0]["embedding"]

  def check_plaintext_nil
    if plaintext.nil?
      self.plaintext = html
    end
  end
end
