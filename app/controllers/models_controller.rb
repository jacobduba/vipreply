class ModelsController < ApplicationController
  before_action :authorize_account_has_model, except: [:index]
  include GeneratorConcern

  def index
    @models = @account.models
  end

  def show
    @examples = Example.where(model_id: @model.id).select(:id, :input, :output).order(id: :asc).all
  end

  def generate_response
    query = params[:query]

    generate_and_show query

    # :see_other forces turbo to reload page
    render "show", status: :see_other
  end

  private

end
