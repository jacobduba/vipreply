require 'net/http'

class ResponderController < ApplicationController
  def index
    render 'search'
  end

  def fetch_embedding(input)
    url = "https://api.openai.com/v1/embeddings"
    headers = {
      "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_KEY")}",
      "Content-Type" => "application/json"
    }
    data = {
      input: input,
      model: "text-embedding-3-large"
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    JSON.parse(response.body)["data"][0]["embedding"]
  end

  def query
    query = params[:query]

    embedding = fetch_embedding(query)

    @neighbor = Example.nearest_neighbors(:input_embedding, embedding, distance: "euclidean").first

    puts @neighbor

    render 'search', status: :see_other
  end
end
