# frozen_string_literal: true

class TemplatesController < ApplicationController
  include GeneratorConcern

  def index
    @templates = @account.inbox.templates.select(:id, :input, :output).order(id: :asc).all
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
      if @regenerate_reply
        @topic_id = strong_params[:topic_id]
      end

      render :new, status: :unprocessable_entity
      return
    end

    if regenerate_reply
      topic = Topic.find(strong_params[:topic_id])
      handle_regenerate_reply(topic)
      return
    end

    render turbo_stream: turbo_stream.append("templates_collection", partial: "template", locals: {template: @template})
  end

  def edit
    @template = Template.find(params[:id])

    @input_errors = []
    @output_errors = []
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
    params.require(:template).permit(:input, :output, :topic_id, :regenerate_reply)
  end
end
