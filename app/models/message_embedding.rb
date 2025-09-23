# frozen_string_literal: true

# app/models/message_embedding.rb
class MessageEmbedding < ApplicationRecord
  EMBEDDING_TOKEN_LIMIT = 32_000

  belongs_to :message
  has_and_belongs_to_many :templates

  validates :message_id, uniqueness: true

  before_create :populate_all

  def populate_all
    self.embedding = if respond_to?(:generate_embedding_sandbox) && Rails.env.development?
      generate_embedding_sandbox
    else
      generate_embedding
    end

    if respond_to?(:generate_embedding_next)
      self.embedding_next = generate_embedding_next
    end
  end

  def generate_embedding
    text = <<~TEXT
      Instruct: Given a customer email, retrieve customer emails that ask the same question.
      Query: Subject: #{message.subject}
      Body: #{message.plaintext}
    TEXT

    # Truncate text to token limit
    encoding = QWEN_TOKENIZER.encode(text)
    if encoding.tokens.size > EMBEDDING_TOKEN_LIMIT
      truncated_ids = encoding.ids[0...EMBEDDING_TOKEN_LIMIT]
      text = QWEN_TOKENIZER.decode(truncated_ids)
    end

    fw = Faraday.new(url: "https://api.fireworks.ai") do |f|
      f.request :retry, {
        max: 10,
        interval: 1,
        backoff_factor: 2,
        retry_statuses: [ 408, 429, 500, 502, 503, 504, 508 ],
        methods: %i[post]
      }
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
