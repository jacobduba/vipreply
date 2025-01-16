class Message < ApplicationRecord
  belongs_to :topic
  has_many :attachments, dependent: :destroy

  def replace_cids_with_urls(host)
    return html unless html

    updated_html = html.dup

    attachments.each do |attachment|
      next unless attachment.content_id

      attachment_url = "#{host}/attachments/#{attachment.id}"

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
    return plaintext.stripe unless plaintext
    lines = plaintext.lines

    cutoff_index = lines.find_index { |line|
      line.start_with?("On") && line.include?("wrote:")
    }

    plaintext.strip unless cutoff_index
    lines[0...cutoff_index].join.strip
  end

  def to_s
    <<~HEREDOC
      Date: #{date}
      From: #{from}
      To: #{to}
      Subject: #{subject}

      #{plaintext}
    HEREDOC
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

    # Save or update attachments
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
end
