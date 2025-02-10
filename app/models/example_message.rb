class ExampleMessage < ApplicationRecord
  belongs_to :inbox
  has_many :examples, as: :source

  # Provide a simple generate_embedding method for dummy examples.
  def generate_embedding
    embedding_text = <<~TEXT
      Subject: #{subject}
      Body:
      #{body}
    TEXT

    fetch_embedding(embedding_text)
  end

  private

  def fetch_embedding(text)
    voyage_api_key = Rails.application.credentials.voyage_api_key
    url = "https://api.voyageai.com/v1/embeddings"
    headers = {
      "Authorization" => "Bearer #{voyage_api_key}",
      "Content-Type" => "application/json"
    }
    data = {
      input: text,
      model: "voyage-3-large",
      output_dimension: 2048
    }
    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    JSON.parse(response.body)["data"][0]["embedding"]
  end
end
