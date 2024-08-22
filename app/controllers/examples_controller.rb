require 'net/http'
require 'uri'

class ExamplesController < ApplicationController
  def new
    @model = Model.find(params[:model_id])
    @example = Example.new
  end

  def index
    @model = Model.find(params[:model_id])
    @examples = Example.where(model_id: @model.id).select(:id, :input, :output).order(id: :asc).all
  end

  def create
    @model = Model.find(params[:model_id])

    params_n = example_params
    input = params_n[:input]
    output = params_n[:output]

    input_embedding = helpers.fetch_embedding(input)

    @example = Example.new(input: input, output: output, input_embedding: input_embedding, model_id: @model.id)

    if @example.save
      render turbo_stream: turbo_stream.append("examples_model", partial: "example", locals: { example: @example })
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @model = Model.find(params[:model_id])
    @example = Example.find(params[:id])
  end

  def update
    @model = Model.find(params[:model_id])
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
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @example = Example.find(params[:id])
    @example.destroy

    render turbo_stream: [
      turbo_stream.remove("example-#{@example.id}"),
      turbo_stream.remove("edit-example-modal")
    ]
  end

  private
    def example_params
      params.require(:example).permit(:input, :output)
    end
end
