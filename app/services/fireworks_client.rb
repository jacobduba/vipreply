class FireworksClient
  def self.embeddings(input:, model: "accounts/fireworks/models/qwen3-embedding-8b", dimensions: 1024)
    response = Net::HTTP.post(
      URI("https://api.fireworks.ai/inference/v1/embeddings"),
      { input: input, model: model, dimensions: dimensions }.to_json,
      {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{Rails.application.credentials.fireworks_api_key}"
      }
    )

    raise "Fireworks API error: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["data"][0]["embedding"]
  end
end
