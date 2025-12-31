class OpenRouterClient
  def self.embeddings(input:, model: "qwen/qwen3-embedding-8b", dimensions: 1024)
    response = Net::HTTP.post(
      URI("https://openrouter.ai/api/v1/embeddings"),
      { input: input, model: model, dimensions: dimensions }.to_json,
      {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{Rails.application.credentials.openrouter_api_key}"
      }
    )

    raise "OpenRouter API error: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["data"][0]["embedding"]
  end

  def self.chat(models:, messages:)
    response = Net::HTTP.post(
      URI("https://openrouter.ai/api/v1/chat/completions"),
      { models: models, messages: messages }.to_json,
      {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{Rails.application.credentials.openrouter_api_key}"
      }
    )

    raise "OpenRouter API error: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
