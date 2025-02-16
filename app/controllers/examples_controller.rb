class ExamplesController < ApplicationController
  before_action :set_example, only: [:show, :edit, :update, :destroy]

  # GET /examples
  def index
    @examples = Example.all
  end

  # GET /examples/:id
  def show
  end

  # GET /examples/new
  def new
    @example = Example.new
  end

  # GET /examples/:id/edit
  def edit
  end

  # POST /examples
  def create
    @example = Example.new(example_params)
    if @example.save
      redirect_to @example, notice: 'Example was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /examples/:id
  def update
    if @example.update(example_params)
      redirect_to @example, notice: 'Example was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /examples/:id
  def destroy
    @example.destroy
    respond_to do |format|
      # For Turbo Streams (Hotwire) if you are using them:
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@example) }
      # For HTML fallback:
      format.html { redirect_back fallback_location: templates_path, notice: 'Example was successfully deleted.' }
    end
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_example
      @example = Example.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    # Adjust the permitted attributes as needed.
    def example_params
      params.require(:example).permit(:template_id, :inbox_id, :source_type, :source_id, :embedding_id)
    end
end
