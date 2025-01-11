# frozen_string_literal: true

module GeneratorConcern
  extend ActiveSupport::Concern

  def fetch_embedding(input)
    openai_api_key = Rails.application.credentials.openai_api_key

    url = "https://api.openai.com/v1/embeddings"
    headers = {
      "Authorization" => "Bearer #{openai_api_key}",
      "Content-Type" => "application/json"
    }
    data = {
      input: input,
      model: "text-embedding-3-large"
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    JSON.parse(response.body)["data"][0]["embedding"]
  end

  def gen_reply(topic, inbox)
    message = topic.messages.order(date: :desc).first # Newest message
    message_str = message.to_s

    embedding = fetch_embedding(message_str)

    neighbors = inbox.templates.nearest_neighbors(:input_embedding, embedding,
      distance: "euclidean").first(1)

    example_prompts = neighbors.map do |neighbor|
      "Example recieved email:\n\n#{neighbor.input}\n\nExample response email:\n\n#{neighbor.output}\n\n"
    end

    examples_for_prompt = example_prompts.join
    email_for_prompt = "Email:\n\n#{message}\n\nResponse:\n\n"

    prompt = "#{examples_for_prompt}#{email_for_prompt}"

    reply = fetch_generation(prompt)
    first_template = neighbors[0]
    template_status = neighbors.empty? ? :no_templates_exist_at_generation : :template_attached

    topic.update!(generated_reply: reply, template: first_template, template_status: template_status) # Cache result in DB

    {
      email: message_str,
      reply: reply,
      template: first_template
    }
  end

  private

  def fetch_generation(prompt)
    openai_api_key = Rails.application.credentials.openai_api_key

    url = "https://api.openai.com/v1/chat/completions"
    headers = {
      "Authorization" => "Bearer #{openai_api_key}",
      "Content-Type" => "application/json"
    }
    data = {
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: <<~HEREDOC
            You are a Customer Support Representative who answers emails.
            You will be given a template containing a example received email and an example response email.
            Then you will given an email and you must generate a response for it using the template.
            Write it in your own words!
            Be compassionate: emphasize with the customer.
            Include a salutation such as Hello or Greetings.
            DO NOT include a closing, such as Best regards or Kind regards."
          HEREDOC
        },
        {
          role: "user",
          content: prompt
        }
      ]
    }

    response = Net::HTTP.post(URI(url), data.to_json, headers).tap(&:value)
    generated_text = JSON.parse(response.body)["choices"][0]["message"]["content"]
    generated_text.strip
  end

  # This method is called when a user clicks the "Regenerate Reply" button
  def handle_regenerate_reply(topic_id)
    topic = Topic.find(topic_id)
    gen_reply(topic, @account.inbox)

    render turbo_stream: [
      turbo_stream.replace("generated_reply_form", partial: "topics/generated_reply_form", locals: {topic: topic}),
      turbo_stream.replace("template_form", partial: "topics/template_form", locals: {input_errors: [], output_errors: [], topic: topic})
    ]
  end
end
