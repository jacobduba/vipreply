class Message < ApplicationRecord
  require "tokenizers"

  EMBEDDING_TOKEN_LIMIT = 8191
  include ActionView::Helpers::TextHelper

  belongs_to :topic
  has_many :attachments, dependent: :destroy
  has_one :message_embedding, dependent: :destroy

  before_save :check_plaintext_nil

  after_save :ensure_embedding_exists, unless: -> { message_embedding.present? }

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
    from_name ? "#{from_name} <#{from_email}>" : from_email.to_s
  end

  def to
    to_name ? "#{to_name} <#{to_email}>" : to_email.to_s
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

  # Modified embedding generation
  def ensure_embedding_exists
    MessageEmbedding.create_for_message(self)
  rescue => e
    Rails.logger.error "Failed to create message embedding for message #{id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
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

  def self.cache_from_provider(topic, message_data)
    case topic.inbox.provider
    when "google_oauth2"
      cache_from_gmail(topic, message_data)
    when "microsoft_office365"
      cache_from_outlook(topic, message_data)
    else
      raise "Unknown provider: #{topic.inbox.provider}"
    end
  end

  def self.cache_from_outlook(topic, message_data)
    # Extract data from Microsoft Graph API response
    message_id = message_data["id"]

    # Handle date parsing
    received_date = begin
      DateTime.parse(message_data["receivedDateTime"])
    rescue
      DateTime.now
    end

    subject = message_data["subject"] || "(No Subject)"

    # Handle sender information
    from_info = message_data.dig("from", "emailAddress") || {}
    from_name = from_info["name"]
    from_email = from_info["address"]

    # Handle recipient information
    to_info = message_data.dig("toRecipients", 0, "emailAddress") || {}
    to_name = to_info["name"]
    to_email = to_info["address"]

    # Parse content
    body_content = message_data["body"] || {}
    html = (body_content["contentType"] == "html") ? body_content["content"] : nil
    plaintext = (body_content["contentType"] == "text") ? body_content["content"] : nil

    # If only one format is available, use it for both
    plaintext ||= ActionView::Base.full_sanitizer.sanitize(html) if html
    html ||= "<div>#{plaintext}</div>" if plaintext

    # Find or initialize message by BOTH message_id AND topic_id to prevent duplicates across providers
    msg = topic.messages.find_or_initialize_by(message_id: message_id)

    msg.assign_attributes(
      date: received_date,
      subject: subject,
      from_name: from_name,
      from_email: from_email,
      to_email: to_email,
      to_name: to_name,
      internal_date: received_date,
      plaintext: plaintext,
      html: html,
      snippet: message_data["bodyPreview"] || "",
      provider_message_id: message_id,
      labels: []  # Microsoft doesn't have the same labels concept
    )

    # Use transaction to handle possible race conditions
    begin
      if msg.changed?
        msg.save!
        Rails.logger.info "Saved message: #{msg.id} for topic: #{topic.id}"
      else
        Rails.logger.info "No changes for message: #{msg.id} for topic: #{topic.id}"
      end
    rescue ActiveRecord::RecordNotUnique => e
      # Handle duplicate key violation - just log and continue
      Rails.logger.warn "Duplicate message detected (#{message_id}): #{e.message}"
      msg = topic.messages.find_by(message_id: message_id) || msg
    end

    # Process attachments if there are any
    if message_data["hasAttachments"] && message_data["attachments"]
      msg.attachments.destroy_all

      message_data["attachments"].each do |attachment_data|
        Attachment.cache_from_provider(msg, {
          attachment_id: attachment_data["id"],
          content_id: attachment_data["contentId"],
          filename: attachment_data["name"] || "attachment.bin",
          mime_type: attachment_data["contentType"] || "application/octet-stream",
          size: attachment_data["size"] ? (attachment_data["size"].to_i / 1024) : 0,
          content_disposition: (attachment_data["isInline"] ? :inline : :attachment)
        })
      rescue => e
        Rails.logger.error "Error saving attachment: #{e.message}"
      end
    end

    msg
  end

  # Returns Message
  def self.cache_from_gmail(topic, message)
    headers = message.payload.headers
    gmail_message_id = message.id
    labels = message.label_ids
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
      provider_message_id: gmail_message_id,
      labels: labels
    )

    if msg.changed?
      msg.save!
      Rails.logger.info "Saved message: #{msg.id}"
    else
      Rails.logger.info "No changes for message: #{msg.id}"
    end

    if msg.labels.include?("SPAM")
      topic.update(is_spam: true)
    end

    topic.save

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

  def tokenizer
    @tokenizer ||= Tokenizers::Tokenizer.from_pretrained("voyageai/voyage-3-large")
  end

  def truncate_embedding_text(text)
    encoding = tokenizer.encode(text)
    return text if encoding.tokens.size <= EMBEDDING_TOKEN_LIMIT

    truncated_ids = encoding.ids[0...EMBEDDING_TOKEN_LIMIT]
    tokenizer.decode(truncated_ids)
  end

  # Modified to store directly on message
  def fetch_embedding(text)
    voyage_api_key = Rails.application.credentials.voyage_api_key
    url = "https://api.voyageai.com/v1/embeddings"

    response = Net::HTTP.post(
      URI(url),
      {
        input: text,
        model: "voyage-3-large",
        output_dimension: 2048
      }.to_json,
      "Authorization" => "Bearer #{voyage_api_key}",
      "Content-Type" => "application/json"
    )

    JSON.parse(response.body)["data"][0]["embedding"]
  rescue => e
    Rails.logger.error "Embedding generation failed: #{e.message}"
    nil
  end

  private

  def check_plaintext_nil
    self.plaintext ||= html
  end
end
