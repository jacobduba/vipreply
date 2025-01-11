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

    input_embedding = fetch_embedding(input)

    @template = @account.inbox.templates.new(input: input, output: output, input_embedding: input_embedding)

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
      topic_id = strong_params[:topic_id]

      topic = Topic.find(topic_id)
      reply = gen_reply(topic, @account.inbox)[:reply]

      render turbo_stream: [
        turbo_stream.replace("generated_reply_form", partial: "topics/generated_reply_form", locals: {topic: topic, generated_reply: reply}),
        turbo_stream.replace("template_form", partial: "topics/template_form", locals: {input_errors: [], output_errors: [], topic_id: topic_id})
      ]
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

    input_embedding = fetch_embedding(input)

    unless @template.update(input: input, output: output, input_embedding: input_embedding)
      @input_errors = @template.errors.full_messages_for(:input)

      @output_errors = @template.errors.full_messages_for(:output)

      render :edit, status: :unprocessable_entity
      return
    end

    if regenerate_reply
      topic_id = strong_params[:topic_id]

      topic = Topic.find(topic_id)
      reply = gen_reply(topic, @account.inbox)[:reply]

      render turbo_stream: [
        turbo_stream.replace("generated_reply_form", partial: "topics/generated_reply_form", locals: {template: @template, generated_reply: reply}),
        turbo_stream.replace("template_form", partial: "topics/template_form", locals: {input_errors: [], output_errors: [], topic_id: topic_id})
      ]
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
