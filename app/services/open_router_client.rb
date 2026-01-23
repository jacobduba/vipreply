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

  def self.chat(models:, messages:, posthog_user_id:)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

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

    parsed = JSON.parse(response.body)
    latency = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    POSTHOG&.capture({
      distinct_id: "user_#{posthog_user_id}",
      event: "$ai_generation",
      properties: {
        "$ai_trace_id" => parsed["id"],
        "$ai_model" => parsed["model"],
        "$ai_provider" => "openrouter",
        "$ai_input_tokens" => parsed.dig("usage", "prompt_tokens"),
        "$ai_output_tokens" => parsed.dig("usage", "completion_tokens"),
        "$ai_latency" => latency
      }
    })

    parsed
  end
end
