# frozen_string_literal: true

module GeneratorConcern
  extend ActiveSupport::Concern

  # This method is called when a user clicks the "Regenerate Reply" button
  def handle_regenerate_reply(topic)
    topic.generate_reply
    topic.save!

    render turbo_stream: [
      turbo_stream.replace("generated_reply_form", partial: "topics/generated_reply_form", locals: {topic: topic, generated_reply: topic.generated_reply}),
      turbo_stream.replace("template_form", partial: "topics/template_form", locals: {input_errors: [], output_errors: [], topic: topic})
    ]
  end
end
