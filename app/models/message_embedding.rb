# frozen_string_literal: true

# app/models/message_embedding.rb
class MessageEmbedding < ApplicationRecord
  EMBEDDING_TOKEN_LIMIT = 32_000

  belongs_to :message
  has_and_belongs_to_many :templates

  validates :message_id, uniqueness: true

  def self.create_for_message(message)
    return if message.message_embedding.present?

    embedding = create_embedding(message)

    if MessageEmbedding.respond_to?(:create_new_embedding)
      new_embedding = create_new_embedding(message)
      message.create_message_embedding!(embedding: embedding, new_embedding: new_embedding)
    else
      message.create_message_embedding!(embedding: embedding)
    end
  end

  def self.create_embedding(message)
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
end
