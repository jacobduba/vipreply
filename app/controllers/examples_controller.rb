require "net/http"
require "uri"

class ExamplesController < ApplicationController
  before_action :authorize_account_has_model 

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
    else
      @input_errors = @example.errors.full_messages_for(:input)
      @output_errors = @example.errors.full_messages_for(:output)

      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @example = Example.find(params[:id])

    @input_errors = []
    @output_errors = []
  end

  def update
    @example = Example.find(params[:id])

    params_n = example_params
    input = params_n[:input]
    output = params_n[:output]

    input_embedding = helpers.fetch_embedding(input)

    if @example.update(input: input, output: output, input_embedding: input_embedding)
      render turbo_stream: [
        turbo_stream.replace("example-#{@example.id}", partial: "example", locals: { example: @example }),
        turbo_stream.remove("edit-example-modal"),
      ]
    else
      @input_errors = @example.errors.full_messages_for(:input)
      @output_errors = @example.errors.full_messages_for(:output)

      render :edit, status: :unprocessable_entity
    end
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
    params.require(:example).permit(:input, :output)
  end
end
