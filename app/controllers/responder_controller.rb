require 'net/http'

class ResponderController < ApplicationController
  def index
    render 'search'
  end

  def query
    query = params[:query]

    embedding = fetch_embedding(query)

    @neighbor = Example.nearest_neighbors(:input_embedding, embedding, distance: "euclidean").first

    example_for_prompt = "Example email:\n\n#{@neighbor.input}\n\n:Example response:\n\n#{@neighbor.output}\n\nExample Output:\n\n"
    email_for_prompt = "Email:\n\n#{query}\n\nResponse:\n\n"

    prompt = "#{example_for_prompt}#{email_for_prompt}"

    puts prompt

    @email = query
    @response = fetch_generation(prompt)

    puts @response

    render 'search', status: :see_other
  end

  private
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

    def fetch_generation(prompt)
      url = "https://api.openai.com/v1/chat/completions"
      headers = {
        "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_KEY")}",
        "Content-Type" => "application/json"
      }
      data = {
          model: "gpt-4o",
          messages: [
            {
              role: "system",
              content: "You are an help desk technician who answers emails. First the user will give you examples containing and email and a response. Then the user will give you an example and you must generate a response for it. Include salutation, addressing the customer formally. Do not include a closing, such as Best regards or Kind regards."
            },
            {
              role: "user",
              content: prompt
            }
          ]
      }

      response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
      JSON.parse(response.body)["choices"][0]["message"]["content"]
    end
end
