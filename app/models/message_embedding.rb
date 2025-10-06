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

    FireworksClient.embeddings(input: text)
  end

  def label_as_used_by_templates(templates)
    templates.each do |template|
      next if template.message_embeddings.include?(self)

      template.message_embeddings << self
    end
  end
end
