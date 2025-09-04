# frozen_string_literal: true

# app/models/message_embedding.rb
class MessageEmbedding < ApplicationRecord
  EMBEDDING_TOKEN_LIMIT = 32_000

  belongs_to :message
  has_and_belongs_to_many :templates

  # Vector search functionality
  has_neighbors :vector, dimensions: 2048

  validates :message_id, uniqueness: true

  def self.create_for_message(message)
    # Skip if message already has an embedding
    return if message.message_embedding.present?

    vector = create_embedding_currrent(message)

    create!(message: message, vector: vector)
  end

  def self.create_embedding_current(message)
    embedding_text = <<~TEXT
      Subject: #{message.subject}
      Body: #{message.plaintext}
    TEXT

    # Truncate text to token limit
    encoding = TOKENIZER.encode(text)
    if encoding.tokens.size > EMBEDDING_TOKEN_LIMIT
      truncated_ids = encoding.ids[0...EMBEDDING_TOKEN_LIMIT]
      text = TOKENIZER.decode(truncated_ids)
    end

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
  end

  def self.create_embedding_new(message)
    embedding_text = <<~TEXT
      Subject: #{message.subject}
      Body: #{message.plaintext}
    TEXT

    # Truncate text to token limit
    encoding = TOKENIZER.encode(text)
    if encoding.tokens.size > EMBEDDING_TOKEN_LIMIT
      truncated_ids = encoding.ids[0...EMBEDDING_TOKEN_LIMIT]
      text = TOKENIZER.decode(truncated_ids)
    end

    voyage_api_key = Rails.application.credentials.voyage_api_key
    url = "https://api.voyageai.com/v1/embeddings"

    response = Net::HTTP.post(
      URI(url),
      {
        input: text,
        model: "voyage-3-large",
        output_dimension: 1024
      }.to_json,
      "Authorization" => "Bearer #{voyage_api_key}",
      "Content-Type" => "application/json"
    )

    JSON.parse(response.body)["data"][0]["embedding"]
  end
end
