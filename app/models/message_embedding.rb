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

  def generate_embedding_sandbox
    groq_api_key = Rails.application.credentials.groq_api_key
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {
      "Authorization" => "Bearer #{groq_api_key}",
      "Content-Type" => "application/json"
    }

    system_prompt = <<~PROMPT
      State the request, question, or information for the last message in this customer email.
    PROMPT

    data = {
      model: "moonshotai/kimi-k2-instruct",
      messages: [
        {
          role: "system",
          content: system_prompt
        },
        {
          role: "user",
          content: "Subject: #{message.subject}\nBody: #{message.plaintext}"
        }
      ]
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers)
    parsed = JSON.parse(response.tap(&:value).body)

    debugger

    kimi_text = parsed["choices"][0]["message"]["content"]
    # text = <<~TEXT
    #   Instruct: Given a customer email, retrieve similiar customer emails with the same question, request, or issue.
    #   Query: Subject: #{message.subject}
    #   Body: #{message.plaintext}
    # TEXT
    text = <<~TEXT
      Instruct: Given a customer email request, question, or notice, retrieve customer emails asking for the same thing .
      Body: #{kimi_text}
    TEXT

    # Truncate text to token limit
    encoding = QWEN_TOKENIZER.encode(text)
    if encoding.tokens.size > EMBEDDING_TOKEN_LIMIT
      truncated_ids = encoding.ids[0...EMBEDDING_TOKEN_LIMIT]
      text = QWEN_TOKENIZER.decode(truncated_ids)
    end

    fireworks_api_key = Rails.application.credentials.fireworks_api_key
    url = "https://api.fireworks.ai/inference/v1/embeddings"

    response = Net::HTTP.post(
      URI(url),
      {
        input: text,
        model: "accounts/fireworks/models/qwen3-embedding-8b",
        dimensions: 1024
      }.to_json,
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{fireworks_api_key}"
    )

    raise "HTTP Error #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["data"][0]["embedding"]
  end
end
