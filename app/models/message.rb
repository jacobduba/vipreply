# frozen_string_literal: true

class Message < ApplicationRecord
  include ActionView::Helpers::TextHelper

  belongs_to :topic
  has_many :attachments, dependent: :destroy
  has_one :message_embedding, dependent: :destroy

  before_save :check_plaintext_nil

  # Embedding is in another model, create that model AFTER message is created (dependent relationship)
  after_save :ensure_embedding_exists, unless: -> { message_embedding }

  def prepare_email_for_rendering(host, index)
    html = replace_cids_with_urls(host)

    doc = Nokogiri::HTML5(html)

    # Don't hide history if it's the first message
    unless index == 0
      # VIPReply
      doc.css(".vip_quote").remove

      # Gmail
      doc.css(".gmail_quote").each do |quote|
        prev = quote.previous_element
        if prev && prev.name == "br"
          prev.remove
        end
        quote.remove
      end

      # Fastmail
      doc.css("blockquote#qt").each do |blockquote|
        prev = blockquote.previous_element

        # Check if previous element contains "On ... wrote:"
        if prev&.text&.match?(/On\s+.+\swrote:/)
          # Check if there's an empty div before the "On ... wrote:" element
          prev_prev = prev.previous_element
          prev_prev.remove if prev_prev && prev_prev.name == "div" && prev_prev.text.strip.empty?

          prev.remove
          blockquote.remove
        end
      end

      # Outlook
      doc.css("#divRplyFwdMsg").each do |div|
        # Check for previous hr element
        p = div.previous_element
        n = div.next_element
        p.remove if p && p.name == "hr"
        n.remove if n && n.name == "div"
        div.remove
      end

      # Apple Mail
      doc.css("div[dir='ltr']").each do |div|
        # Check if this div contains a blockquote with type='cite'
        blockquote = div.css("blockquote[type='cite']").first
        if blockquote&.text&.match?(/On\s+.+\s+at\s+.+,\s+.+\s+wrote:/)
          # Check if there's a following blockquote[type='cite']
          next_element = div.next_element
          if next_element && next_element.name == "blockquote" && next_element["type"] == "cite"
            div.remove
            next_element.remove
          end
        end
      end

      # Yahoo
      doc.css("p.yahoo-quoted-begin").each do |p|
        # for some reason yahoo has been putting part of the message in a DIV
        # LOL so the remove trailing elements doesnt *quite* work
        prev_element = p.previous_element
        if prev_element && prev_element.name == "br"
          prev_element.remove
        end

        # Check if next element is a blockquote and remove it first
        next_element = p.next_element
        if next_element && next_element.name == "blockquote"
          next_element.remove
        end
        p.remove
      end
    end

    # Remove trailing empty elements or elements with only br
    body = doc.at("body") || doc
    last_element = body.children.last
    while last_element&.element? &&
        (last_element.children.empty? ||
         (last_element.children.size == 1 && last_element.children.first.name == "br"))
      last_element.remove
      last_element = body.children.last
    end

    doc.css("a").each do |link|
      link["target"] = "_blank"
      link["rel"] = "noopener noreferrer"
    end

    <<~HTML
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&display=swap" rel="stylesheet">
        <style>
          body { font-family: 'Inter', sans-serif; font-size: 16px; }
          img { max-width: 100%; height: auto; }
        </style>
      </head>
      <body>
        #{doc.to_html}
      </body>
    HTML
  end

  def replace_cids_with_urls(host)
    return simple_format(plaintext) unless html

    updated_html = html.dup

    attachments.each do |attachment|
      next unless attachment.content_id

      attachment_url = Rails.application.routes.url_helpers.attachment_url(attachment, host: host)
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

  # Looks like this isn't being used right now!
  # I intend to switch to this to improve embedding quality.
  # # Stipe everything after "On .... wrote:"
  # # Used for embedding vector
  # def message_without_history
  #   return html unless plaintext
  #   lines = plaintext.lines

  #   cutoff_index = lines.find_index { |line|
  #     line.start_with?("On") && line.include?("wrote:")
  #   }

  #   plaintext.strip unless cutoff_index
  #   lines[0...cutoff_index].join.strip
  # end

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
    create_message_embedding! unless message_embedding
  end

  # Returns raw reply
  def create_reply(reply_text, account)
    # Determine the 'from' and 'to' fields using the most recent message
    from_address = "#{account.name} <#{account.email}>"
    to_address = if from_email == account.email
      to
    else
      from
    end

    subject = "Re: #{topic.subject}"

    email_body_plaintext = create_plaintext_reply(reply_text)
    email_body_html = create_html_reply(reply_text)

    in_reply_to = message_id
    references = topic.messages.order(date: :asc).map(&:message_id).join(" ")

    email = Mail.new do
      from from_address
      to to_address
      subject subject

      text_part do
        body email_body_plaintext
      end

      html_part do
        content_type "text/html; charset=UTF-8"
        body email_body_html
      end

      header["In-Reply-To"] = in_reply_to
      header["References"] = references
    end

    email.encoded # return raw email
  end

  def create_plaintext_reply(reply_text)
    unless plaintext
      return reply_text
    end

    quoted_plaintext = plaintext.lines.map do |line|
      if line.starts_with?(">")
        ">#{line}"
      else
        "> #{line}"
      end
    end.join

    <<~PLAINTEXT
      #{reply_text}

      On #{Time.current.strftime("%a, %b %d, %Y at %I:%M %p")}, #{from} wrote:
      #{quoted_plaintext}
    PLAINTEXT
  end

  def create_html_reply(reply_text)
    <<~HTML
      #{simple_format(reply_text)}

      <div class="vip_quote">
        <p>On #{Time.current.strftime("%a, %b %d, %Y at %I:%M %p")}, #{from} wrote:</p>
        <blockquote>
          #{html}
        </blockquote>
      </div>
    HTML
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
    Honeybadger.context({
      topic_id: topic.id,
      gmail_message: message.to_h
    })

    headers = message.payload.headers
    gmail_message_id = message.id
    labels = message.label_ids || []

    date_header = headers.find { |h| h.name.downcase == "date" }
    date = date_header ? DateTime.parse(date_header.value) : DateTime.current

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

    # These lines are a bit of a mouthful... use plaintext or html if there ELSE adapt plaintext or html if there ELSE empty string
    plaintext = collected_parts[:plain] ||
      (collected_parts[:html] && ActionView::Base.full_sanitizer.sanitize(collected_parts[:html])) ||
      ""
    html = collected_parts[:html] ||
      (collected_parts[:plain] && simple_format(collected_parts[:plain])) ||
      ""
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

    # Sometimes we get duplicate key errors, this allows me to inspect.
    Honeybadger.context({
      message_id: message_id
    })

    begin
      msg.save! if msg.changed?
    rescue ActiveRecord::RecordNotUnique
      # Race condition: another transaction already created this message
      # Since the message already exists, we can safely continue
      return topic.messages.find_by!(message_id: message_id)
    end

    topic.is_spam = true if msg.labels.include?("SPAM")

    # idk why this topic.save was here.
    # if this commit is old and no issues... delete
    # topic.save!

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
    elsif part.body.data
      # Has inline content - process based on mime_type
      # Gmail data comes as ASCII-8BIT bytes, normalize to UTF-8 to prevent encoding conflicts
      if part.mime_type == "text/plain"
        result[:plain] = part.body.data.force_encoding("UTF-8").scrub
      elsif part.mime_type == "text/html"
        result[:html] = part.body.data.force_encoding("UTF-8").scrub
      end
    elsif part.body.attachment_id
      # It's an attachment - process attachment metadata
      cid_header = part.headers.find { |h| h.name.downcase == "content-id" }&.value
      x_attachment_id = part.headers.find { |h| h.name.downcase == "x-attachment-id" }&.value
      content_disposition_header = part.headers.find { |h| h.name.downcase == "content-disposition" }&.value

      cid = if x_attachment_id
        "cid:#{x_attachment_id}" # if attachment id provided use it directly
      elsif cid_header
        "cid:#{cid_header[1..-2]}" # cid headers are in brackets <cid:...> so strip brackets
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
    result
  end

  # Returns all the attachments that ARE NOT inline
  def get_file_attachments
    # content_id.nil? - Someth
    attachments.select {
      it.content_disposition == "attachment" ||
        it.content_id.nil? # Ran into case where disposition was inline
      # but no Content-ID provided. Since we cannot show inline, show
      # in attachment list so the user can access it.
    }
  end

  private

  def check_plaintext_nil
    self.plaintext ||= html
  end
end
