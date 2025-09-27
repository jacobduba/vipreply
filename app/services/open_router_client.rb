class OpenRouterClient
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
