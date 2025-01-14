class Topic < ApplicationRecord
  belongs_to :inbox
  belongs_to :template, optional: true

  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages

  enum :template_status, [:no_templates_exist_at_generation, :template_removed, :template_attached, :skipped_no_reply_needed]

  def generate_reply
    message = messages.order(date: :desc).first # Newest message
    message_str = message.to_s

    neighbor = Template.find_similar(message_str)

    example_prompt = if neighbor
      <<~HEREDOC
        Example recieved email:
        #{neighbor.input}
        Example response email:
        #{neighbor.output}
      HEREDOC
    else
      ""
    end

    email_for_prompt = <<~HEREDOC
      Email:
      #{message}
      Response:
    HEREDOC

    prompt = "#{example_prompt}#{email_for_prompt}"

    reply = fetch_generation(prompt)
    template_status = neighbor ? :template_attached : :no_templates_exist_at_generation

    self.generated_reply = reply
    self.template = neighbor
    self.template_status = template_status
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
end
