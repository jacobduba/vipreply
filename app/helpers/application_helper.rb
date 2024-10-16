module ApplicationHelper
  def fetch_embedding(input)
    url = "https://api.openai.com/v1/embeddings"
    headers = {
      "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_KEY")}",
      "Content-Type" => "application/json",
    }
    data = {
      input: input,
      model: "text-embedding-3-large",
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    JSON.parse(response.body)["data"][0]["embedding"]
  end
end
