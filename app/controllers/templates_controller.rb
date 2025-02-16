# frozen_string_literal: true

class TemplatesController < ApplicationController
  include GeneratorConcern

  def index
    @templates = @account.inbox.templates.includes(examples: :source).order(id: :asc)
  end

  def new
    @template = Template.new
    @input_errors = []
    @output_errors = []
    @regenerate_reply = params[:regenerate_reply] == "true"
    @topic_id = params[:topic_id]
  end

  def create
    strong_params = template_params
    input = strong_params[:input]
    output = strong_params[:output]
    regenerate_reply = strong_params[:regenerate_reply] == "true"

    @template = @account.inbox.templates.new(input: input, output: output)

    unless @template.save
      @input_errors = @template.errors.full_messages_for(:input)
      @output_errors = @template.errors.full_messages_for(:output)
      @regenerate_reply = regenerate_reply
      @topic_id = strong_params[:topic_id] if @regenerate_reply
      render :new, status: :unprocessable_entity
      return
    end

    if strong_params[:example_message].present?
      message_text = strong_params[:example_message].strip
      unless message_text.blank?
        example_message = ExampleMessage.create!(
          inbox: @template.inbox,
          subject: "Example",
          body: message_text
        )
        Example.create!(
          template: @template,
          inbox: @template.inbox,
          source: example_message
        )
      end
    end

    if regenerate_reply
      topic = Topic.find(strong_params[:topic_id])
      handle_regenerate_reply(topic)
      return
    end

    redirect_to templates_path, notice: "Template created successfully"
  end

  def edit
    @template = Template.find(params[:id])
    @input_errors = []
    @output_errors = []
    @existing_examples = @template.examples.includes(source: :examples)
  end

  def update
    @template = Template.find(params[:id])
    strong_params = template_params
    input = strong_params[:input]
    output = strong_params[:output]
    regenerate_reply = strong_params[:regenerate_reply] == "true"

    unless @template.update(input: input, output: output)
      @input_errors = @template.errors.full_messages_for(:input)
      @output_errors = @template.errors.full_messages_for(:output)
      render :edit, status: :unprocessable_entity
      return
    end

    if strong_params[:example_message].present?
      message_text = strong_params[:example_message].strip
      unless message_text.blank?
        example_message = ExampleMessage.create!(
          inbox: @template.inbox,
          subject: "Example",
          body: message_text
        )
        Example.create!(
          template: @template,
          inbox: @template.inbox,
          source: example_message
        )
      end
    end

    if regenerate_reply
      topic = Topic.find(strong_params[:topic_id])
      handle_regenerate_reply(topic)
      return
    end

    render turbo_stream: [
      turbo_stream.replace("template-#{@template.id}", partial: "template", locals: {template: @template}),
      turbo_stream.remove("edit-template-modal")
    ]
  end

  def destroy
    @template = Template.find(params[:id])
    @template.destroy

    render turbo_stream: [
      turbo_stream.remove("template-#{@template.id}"),
      turbo_stream.remove("edit-template-modal")
    ]
  end

  private

  def template_params
    params.require(:template).permit(:input, :output, :topic_id, :regenerate_reply, :example_message)
  end
end
