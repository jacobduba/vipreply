require 'net/http'
require 'uri'

class ModelsController < ApplicationController
  def index
    @models = Model.all
  end

  def show
    @model = Model.find(params[:id])
  end

  def generate_response
    @model = Model.find(params[:model_id])
    query = params[:query]

    embedding = helpers.fetch_embedding(query)

    neighbors = Example.where(model_id: @model.id).nearest_neighbors(:input_embedding, embedding, distance: "euclidean").first(3)

    example_prompts = neighbors.map do |neighbor|
      "Example email:\n\n#{neighbor.input}\n\nExample response:\n\n#{neighbor.output}\n\n"
    end

    examples_for_prompt = example_prompts.join
    email_for_prompt = "Email:\n\n#{query}\n\nResponse:\n\n"

    prompt = "#{examples_for_prompt}#{email_for_prompt}"

    puts prompt

    @email = query
    @response = fetch_generation(prompt)

    render 'show', status: :see_other
  end

  private
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
              content: <<~HEREDOC
                You are a compassionate help desk technician who answers emails.
                First the user will give you examples containing and email and a response.
                Then the user will give you an email and you must generate a response for it using information and tone from the examples.
                Do not include a salutation such as Hello or Greetings.
                Do not include a closing, such as Best regards or Kind regards."
              HEREDOC
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
