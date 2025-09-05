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

  def self.create_for_messages(messages)
    return [] if messages.blank?
    # Skip if message already  as an embedding
    # return if message.message_embedding.present?

    embeddings = cur_create_embeddings(messages)
    new_embeddings = new_create_embeddings(messages)

    messages.zip(embeddings, new_embeddings).each do |message, embedding, new_embedding|
      message.create_message_embedding!(vector: embedding, embedding_new: new_embedding)
    end
  end

  def self.cur_create_embeddings(messages)
    input_texts = messages.map do |message|
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

      text
    end

    voyage_api_key = Rails.application.credentials.voyage_api_key
    url = "https://api.voyageai.com/v1/embeddings"

    response = Net::HTTP.post(
      URI(url),
      {
        input: input_texts,
        model: "voyage-3-large",
        output_dimension: 2048
      }.to_json,
      "Authorization" => "Bearer #{voyage_api_key}",
      "Content-Type" => "application/json"
    )

    unless response.is_a?(Net::HTTPSuccess)
      puts "HTTP Error #{response.code}: #{response.message}"
      puts "Response body: #{response.body}"
      puts "Response headers: #{response.to_hash}"
      return
    end

    JSON.parse(response.body)["data"].map { |item| item["embedding"] }
  end

  def self.new_create_embeddings(messages)
    input_texts = messages.map do |message|
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

      text
    end

    voyage_api_key = Rails.application.credentials.voyage_api_key
    url = "https://api.voyageai.com/v1/embeddings"

    response = Net::HTTP.post(
      URI(url),
      {
        input: input_texts,
        model: "voyage-3-large",
        output_dimension: 1024
      }.to_json,
      "Authorization" => "Bearer #{voyage_api_key}",
      "Content-Type" => "application/json"
    )

    unless response.is_a?(Net::HTTPSuccess)
      puts "HTTP Error #{response.code}: #{response.message}"
      puts "Response body: #{response.body}"
      puts "Response headers: #{response.to_hash}"
      return
    end

    JSON.parse(response.body)["data"].map { |item| item["embedding"] }
  end
end
