class Message < ApplicationRecord
  require "tokenizers"

  EMBEDDING_TOKEN_LIMIT = 8191
  include ActionView::Helpers::TextHelper

  belongs_to :topic
  has_many :attachments, dependent: :destroy
  has_one :message_embedding, dependent: :destroy

  before_save :check_plaintext_nil

  after_save :ensure_embedding_exists, unless: -> { message_embedding.present? }

  def prepare_email_for_rendering(host, index)
    html = replace_cids_with_urls(host)

    doc = Nokogiri::HTML5(html)

    # Don't hide history if it's the first message
    unless index == 0
      doc.xpath("//text()").each do |text_node|
        if text_node.text.match?(/On\s+.+\swrote:/)
          parent_node = text_node.parent
          next_node = parent_node.next_element
          if next_node && next_node.name == "blockquote"
            next_node.remove
            text_node.remove
          end
        end
      end
    end

    doc.css("a").each do |link|
      link["target"] = "_blank"
      link["rel"] = "noopener noreferrer"
    end

    <<~HTML
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&display=swap" rel="stylesheet">
      <div style="font-family: 'Inter', sans-serif; font-size: 16px;">
        #{doc.to_html}
      </div>
    HTML
  end

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

  # Returns Message
  def self.cache_from_gmail(topic, message)
    headers = message.payload.headers
    gmail_message_id = message.id
    labels = message.label_ids

    date_header = headers.find { |h| h.name.downcase == "date" }
    date = date_header ? DateTime.parse(date_header.value) : DateTime.now

    subject_header = headers.find { |h| h.name.downcase == "subject" }
    subject = subject_header&.value
    subject = "(No subject)" if subject.nil? || subject.empty?

    from_header_obj = headers.find { |h| h.name.downcase == "from" }
    from_header = from_header_obj&.value || "(Email not provided)"
    from_name, from_email = parse_email_header(from_header)

    to_header_obj = headers.find { |h| h.name.downcase == "to" }
    to_header = to_header_obj&.value || "(Email not provided)"
    to_name, to_email = parse_email_header(to_header)

    message_id_header = headers.find { |h| h.name.downcase == "message-id" }
    message_id = message_id_header&.value || "#{SecureRandom.uuid}@generated.id"

    # Gmail's date for message in milliseconds. That's why divide by 1000.
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
      gmail_message_id: gmail_message_id,
      labels: labels
    )

    if msg.changed?
      msg.save!
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
        # Sometimes content-disposition is not present in the header
        # Thus make it inline else will violate content-disposition being non-null
        content_disposition = content_disposition_header&.split(";")&.first&.strip || "inline"
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
