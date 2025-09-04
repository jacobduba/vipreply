# frozen_string_literal: true

# app/models/message_embedding.rb
class MessageEmbedding < ApplicationRecord
  EMBEDDING_TOKEN_LIMIT = 32_000

  belongs_to :message
  has_and_belongs_to_many :templates

  # Vector search functionality
  has_neighbors :vector, dimensions: 2048
  has_neighbors :embedding_new, dimensions: 1024

  validates :message_id, uniqueness: true

  def self.create_for_message(message)
    # Skip if message already has an embedding
    return if message.message_embedding.present?

    vector = cur_create_embedding(message)
    embedding_new = new_create_embedding(message)

    create!(message: message, vector: vector, embedding_new: embedding_new)
  end

  def self.cur_create_embedding(message)
    text = <<~TEXT
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

  def self.new_create_embedding(message)
    text = <<~TEXT
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
