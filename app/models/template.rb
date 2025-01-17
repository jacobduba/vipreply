# frozen_string_literal: true

class Template < ApplicationRecord
  # OpenAI lets us submit 8191 tokens... if the characters are under 3000
  # characters we can't go over 8191 tokens lol
  MAX_INPUT_OUTPUT_SIZE = 3000

  belongs_to :inbox
  has_many :topics

  has_neighbors :input_embedding
  validates :input, uniqueness: true, length: {in: 3..MAX_INPUT_OUTPUT_SIZE}
  validates :output, length: {in: 3..MAX_INPUT_OUTPUT_SIZE}

  before_save :generate_input_embedding, if: :input_changed?

  before_destroy :remove_template_from_topics

  def self.find_best(message, inbox)
    message_str_without_hist = message.message_without_history

    embedding = fetch_embedding(message_str_without_hist)

    inbox.templates.nearest_neighbors(:input_embedding, embedding, distance: :cosine).first
  end

  def self.fetch_embedding(input)
    openai_api_key = Rails.application.credentials.openai_api_key

    url = "https://api.openai.com/v1/embeddings"
    headers = {
      "Authorization" => "Bearer #{openai_api_key}",
      "Content-Type" => "application/json"
    }
    data = {
      input: input,
      model: "text-embedding-3-large"
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    JSON.parse(response.body)["data"][0]["embedding"]
  end

  private

  def remove_template_from_topics
    # Don't nullify, we just set the status to template_removed and it's assumed the template is deleted
    topics.update_all(template_status: :template_removed, template_id: nil)
  end

  def generate_input_embedding
    self.input_embedding = Template.fetch_embedding(input)
  end
end
