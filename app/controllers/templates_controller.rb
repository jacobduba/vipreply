# frozen_string_literal: true

class TemplatesController < ApplicationController
  include GeneratorConcern

  def index
    @templates = @account.inbox.templates.select(:id, :input, :output).order(id: :asc).all
  end

  def new
    regenerate_query = params[:regenerate]

    @template = Template.new

    @input_errors = []
    @output_errors = []

    @regenerate = regenerate_query == "true"
  end

  def create
    strong_params = template_params
    input = strong_params[:input]
    output = strong_params[:output]
    create_and_regenerate = strong_params[:create_and_regenerate] && strong_params[:create_and_regenerate] == "true"

    input_embedding = fetch_embedding(input)

    @template = @account.inbox.templates.new(input: input, output: output, input_embedding: input_embedding)

    unless @template.save
      @input_errors = @template.errors.full_messages_for(:input)
      @output_errors = @template.errors.full_messages_for(:output)

      render :new, status: :unprocessable_entity
      return
    end

    if create_and_regenerate
      generate_and_show strong_params[:query]
      render turbo_stream: [
        turbo_stream.replace("generated_response", partial: "models/generated_response"),
        turbo_stream.replace("referenced_template_form", partial: "models/referenced_template_form")
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
    save_and_regenerate = strong_params[:save_and_regenerate] && strong_params[:save_and_regenerate] == "true"

    input_embedding = helpers.fetch_embedding(input)

    unless @template.update(input: input, output: output, input_embedding: input_embedding)
      @input_errors = @template.errors.full_messages_for(:input)

      @output_errors = @template.errors.full_messages_for(:output)

      render :edit, status: :unprocessable_entity
      return
    end

    if save_and_regenerate
      generate_and_show strong_params[:query]
      render turbo_stream: [
        turbo_stream.replace("generated_response", partial: "models/generated_response"),
        turbo_stream.replace("referenced_template_form", partial: "models/referenced_template_form")
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
    params.require(:template).permit(:input, :output, :save_and_regenerate, :query, :create_and_regenerate)
  end
end
