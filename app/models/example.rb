class Example < ApplicationRecord
  # OpenAI lets us submit 8191 tokens... if the characters are under 8191
  # characters we can't go over 8191 tokens lol
  EMBEDDING_CHAR_LIMIT = 8191

  belongs_to :template
  belongs_to :message
  belongs_to :inbox

  has_neighbors :message_plaintext_embedding

  validates :message, presence: true

  before_save :generate_message_plaintext_embedding, if: :message_id_changed?

  def self.fetch_embedding(text)
    truncated_text = text.to_s.strip[0...EMBEDDING_CHAR_LIMIT]

    openai_api_key = Rails.application.credentials.openai_api_key

    url = "https://api.openai.com/v1/embeddings"
    headers = {
      "Authorization" => "Bearer #{openai_api_key}",
      "Content-Type" => "application/json"
    }
    data = {
      input: truncated_text,
      model: "text-embedding-3-large"
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    JSON.parse(response.body)["data"][0]["embedding"]
  end

  def self.find_best
    embedding = fetch_embedding(message.plaintext)

    inbox.examples.nearest_neighbors(:input_embedding, embedding, distance: :cosine).first
  end

  def generate_message_plaintext_embedding
    self.message_plaintext_embedding = Example.fetch_embedding(message.plaintext)
  end
end
