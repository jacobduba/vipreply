class Example < ApplicationRecord
  # OpenAI lets us submit 8191 tokens... if the characters are under 8191
  # characters we can't go over 8191 tokens lol
  EMBEDDING_CHAR_LIMIT = 8191

  belongs_to :template
  belongs_to :message

  has_neighbors :message_plaintext_embedding

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
end
