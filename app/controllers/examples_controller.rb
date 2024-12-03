require "net/http"
require "uri"

class ExamplesController < ApplicationController
  before_action :authorize_account_has_model
  include GeneratorConcern

  def index
    @examples = Example.where(model_id: @model.id).select(:id, :input, :output).order(id: :asc).all
  end

  def new
    @example = Example.new

    @input_errors = []
    @output_errors = []
  end

  def create
    params_n = example_params
    input = params_n[:input]
    output = params_n[:output]

    input_embedding = helpers.fetch_embedding(input)

    @example = Example.new(input: input, output: output, input_embedding: input_embedding, model_id: @model.id)

    if @example.save
      render turbo_stream: turbo_stream.append("examples_collection", partial: "example", locals: { example: @example })
      return
    end

    @input_errors = @example.errors.full_messages_for(:input)
    @output_errors = @example.errors.full_messages_for(:output)

    render :new, status: :unprocessable_entity
  end

  def edit
    @example = Example.find(params[:id])

    @input_errors = []
    @output_errors = []
  end

  def update
    @example = Example.find(params[:id])

    strong_params = example_params
    input = strong_params[:input]
    output = strong_params[:output]
    save_and_regenerate = strong_params[:save_and_regenerate]

    input_embedding = helpers.fetch_embedding(input)

    unless @example.update(input: input, output: output, input_embedding: input_embedding)
      @input_errors = @example.errors.full_messages_for(:input)

      @output_errors = @example.errors.full_messages_for(:output)

      render :edit, status: :unprocessable_entity
      return
    end

    if save_and_regenerate
      generate_and_show "i guess"
      render "models/show", status: :see_other
      return
    end

    render turbo_stream: [
      turbo_stream.replace("example-#{@example.id}", partial: "example", locals: { example: @example }),
      turbo_stream.remove("edit-example-modal"),
    ]
  end

  def destroy
    @example = Example.find(params[:id])
    @example.destroy

    render turbo_stream: [
      turbo_stream.remove("example-#{@example.id}"),
      turbo_stream.remove("edit-example-modal"),
    ]
  end

  private

  def example_params
    params.require(:example).permit(:input, :output, :save_and_regenerate)
  end
end
