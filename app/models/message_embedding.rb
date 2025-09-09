# frozen_string_literal: true

# app/models/message_embedding.rb
class MessageEmbedding < ApplicationRecord
  EMBEDDING_TOKEN_LIMIT = 32_000

  belongs_to :message
  has_and_belongs_to_many :templates

  validates :message_id, uniqueness: true

  before_create :populate_all

  def populate_all
    if respond_to?(:generate_embedding_sandbox) && Rails.env.development?
      populate_sandbox
    else
      populate
    end

    if respond_to?(:generate_embedding_next)
      populate_next
    end
  end

  def populate
    self.embedding = generate_embedding
  end

  def populate_next
    self.embedding_next = generate_embedding_next
  end

  def populate_sandbox
    self.embedding = generate_embedding_sandbox
  end

  def generate_embedding
    text = <<~TEXT
      Subject: #{message.subject}
      Body: #{message.plaintext}
    TEXT

    # Truncate text to token limit
    encoding = COHERE_TOKENIZER.encode(text)
    if encoding.tokens.size > EMBEDDING_TOKEN_LIMIT
      truncated_ids = encoding.ids[0...EMBEDDING_TOKEN_LIMIT]
      text = COHERE_TOKENIZER.decode(truncated_ids)
    end

    cohere_api_key = Rails.application.credentials.cohere_api_key
    url = "https://api.cohere.com/v2/embed"

    response = Net::HTTP.post(
      URI(url),
      {
        texts: [text],
        input_type: "clustering", # we are clustering the documents into topics
        model: "embed-v4.0",
        output_dimension: 1024
      }.to_json,
      "accept" => "application/json",
      "content-type" => "application/json",
      "Authorization" => "bearer #{cohere_api_key}"
    )

    raise "HTTP Error #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["embeddings"]["float"][0]
  end

  def generate_embedding_next
    subject = message.subject
    body = message.plaintext[0, 10_000]

    # Todo: move this into my own interface? or use rubyllm
    groq = Faraday.new(url: "https://api.groq.com") do |f|
      f.request :retry, {
        max: 10,
        interval: 1,
        backoff_factor: 2,
        retry_statuses: [408, 429, 500, 502, 503, 504, 508]
      }
      f.request :authorization, "Bearer", Rails.application.credentials.groq_api_key
      f.request :json
      f.response :json, content_type: "application/json"
    end.post("openai/v1/chat/completions", {
      model: "moonshotai/kimi-k2-instruct-0905",
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            Generate a description of a customer request for the last message in this customer email.
            Do not include names.
          PROMPT
        },
        {
          role: "user",
          content: "Subject: #{subject}\nBody: #{body}"
        }
      ]
    })

    begin
      self.preembed_text = groq.body["choices"][0]["message"]["content"]
    rescue
      Rails.logger.error("Groq payload: #{groq.inspect}")
      raise
    end

    text = <<~TEXT
      Instruct: Given a description of a customer request, retrieve descriptions of customer requests that require the same answer.
      Body: #{preembed_text}
    TEXT

    # Truncate text to token limit
    encoding = QWEN_TOKENIZER.encode(text)
    if encoding.tokens.size > EMBEDDING_TOKEN_LIMIT
      truncated_ids = encoding.ids[0...EMBEDDING_TOKEN_LIMIT]
      text = QWEN_TOKENIZER.decode(truncated_ids)
    end

    fw = Faraday.new(url: "https://api.fireworks.ai") do |f|
      f.request :retry,
        max: 10,
        interval: 1,
        backoff_factor: 2,
        retry_statuses: [408, 503, 508],
        exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError]
      f.request :authorization, "Bearer", Rails.application.credentials.fireworks_api_key
      f.request :json
      f.response :json, content_type: "application/json"
    end.post("inference/v1/embeddings", {
      input: text,
      model: "accounts/fireworks/models/qwen3-embedding-8b",
      dimensions: 1024
    })

    fw.body["data"][0]["embedding"]
  end
end
