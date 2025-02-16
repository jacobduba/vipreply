# frozen_string_literal: true

module GeneratorConcern
  extend ActiveSupport::Concern

  # Generate Reply button
  def handle_regenerate_reply(topic)
    topic.generate_reply
    topic.save!
    render turbo_stream: [
      turbo_stream.replace("generated_reply_form", partial: "topics/generated_reply_form", locals: {topic: topic, generated_reply: topic.generated_reply}),
      turbo_stream.replace("template_form", partial: "topics/template_form", locals: {
        input_errors: [],
        output_errors: [],
        topic: topic
      })
    ]
  end

  # Find Templates button
  def handle_find_templates(topic)
    message = topic.messages.order(date: :desc).first

    best_templates = message ? Example.find_best_templates(message, topic.inbox) : []

    topic.templates = best_templates
    topic.save!

    render turbo_stream: [
      turbo_stream.replace("template_form", partial: "templates/template_form", locals: {
        input_errors: [],
        output_errors: [],
        topic: topic,
        template: (topic.templates.any? ? topic.templates.first : Template.new),
        show_delete: (topic.templates.any? ? topic.templates.first.persisted? : false)
      })
    ]
  end
end
