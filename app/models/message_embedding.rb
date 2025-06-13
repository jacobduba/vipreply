# frozen_string_literal: true

# app/models/message_embedding.rb
class MessageEmbedding < ApplicationRecord
  belongs_to :message
  has_and_belongs_to_many :templates

  # Vector search functionality
  has_neighbors :vector, dimensions: 2048

  validates :message_id, uniqueness: true

  def self.create_for_message(message)
    # Skip if message already has an embedding
    return if message.message_embedding.present?

    embedding_text = <<~TEXT
      Subject: #{message.subject}
      Body: #{message.plaintext}
    TEXT

    embedding_text = message.truncate_embedding_text(embedding_text)
    vector = message.fetch_embedding(embedding_text)

    create!(message: message, vector: vector)
  end
end
