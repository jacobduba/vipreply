# frozen_string_literal: true

module GeneratorConcern
  extend ActiveSupport::Concern

  # Generate Reply button handler
  def handle_regenerate_reply(topic)
    topic.generate_reply
    topic.save!
    render turbo_stream: [
      turbo_stream.replace("generated_reply_form",
        partial: "topics/generated_reply_form",
        locals: {topic: topic, generated_reply: topic.generated_reply}),
      turbo_stream.replace("template_form",
        partial: "topics/template_form",
        locals: {input_errors: [], output_errors: [], topic: topic})
    ]
  end

  # Find Templates button handler
  def handle_find_templates(topic)
    topic.find_best_templates
    render turbo_stream: [
      turbo_stream.replace("template_form",
        partial: "topics/template_form",
        locals: {input_errors: [], output_errors: [], topic: topic}),
      turbo_stream.replace("template-selector-body",
        partial: "topics/template_selector_body",
        locals: {templates: topic.templates})
    ]
  end
end
