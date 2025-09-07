# frozen_string_literal: true

# app/models/message_embedding.rb
class MessageEmbedding < ApplicationRecord
  EMBEDDING_TOKEN_LIMIT = 32_000

  belongs_to :message
  has_and_belongs_to_many :templates

  validates :message_id, uniqueness: true

  def self.create_for_message(message)
    return if message.message_embedding.present?

    if MessageEmbedding.respond_to?(:create_new_embedding)
      embedding = create_embedding(message)
      embedding_new = create_new_embedding(message)
      message.create_message_embedding!(embedding: embedding, new_embedding: new_embedding)
    else
      embedding = create_embedding(message)
      message.create_message_embedding!(embedding: embedding)
    end
  end

  def self.create_embedding(message)
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

    raise "HTTP Error #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["data"][0]["embedding"]
  end
end
