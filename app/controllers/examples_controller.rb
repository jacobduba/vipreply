require 'net/http'
require 'uri'

class ExamplesController < ApplicationController
  def new
    @example = Example.new
  end

  def index
    @examples = Example.select(:id, :input, :output).all
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

  def create
    params_n = example_params
    input = params_n[:input]
    output = params_n[:output]

    input_embedding = fetch_embedding(input)

    @example = Example.new(input: input, output: output, input_embedding: input_embedding)

    if @example.save
      redirect_to "/"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def example_params
      params.require(:example).permit(:input, :output)
    end
end
