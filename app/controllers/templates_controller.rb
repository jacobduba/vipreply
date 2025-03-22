# frozen_string_literal: true

# app/controllers/templates_controller.rb
class TemplatesController < ApplicationController
  include GeneratorConcern

  before_action :set_template, only: [:edit, :update, :destroy]

  def index
    @templates = @account.inbox.templates.order(id: :asc)
  end

  def new
    @template = Template.new
    @input_errors = []
    @output_errors = []
    @regenerate_reply = params[:regenerate_reply] == "true"
    @topic_id = params[:topic_id]
  end

  def create
    @template = @account.inbox.templates.new(template_params)
    regenerate = params[:template][:regenerate_reply] == "true"
    topic_id = params[:template][:topic_id]

    if @template.save
      handle_regeneration(topic_id) if regenerate
      redirect_to templates_path, notice: "Template created successfully"
    else
      @input_errors = @template.errors.full_messages_for(:input)
      @output_errors = @template.errors.full_messages_for(:output)
      render :new
    end
  end

  def edit
    @input_errors = []
    @output_errors = []
  end

  def update
    unless @template.update(template_params)
      @input_errors = @template.errors.full_messages_for(:input)
      @output_errors = @template.errors.full_messages_for(:output)
      render :edit
      return
    end

    redirect_to templates_path, notice: "Template updated successfully"
  end

  def destroy
    @template.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(@template),
          turbo_stream.remove("edit-template-modal")
        ]
      end
      format.html { redirect_to templates_path, notice: "Template was successfully deleted." }
    end
  end

  private

  def set_template
    @template = Template.find(params[:id])
  end

  def template_params
    params.require(:template).permit(:input, :output)
  end

  def handle_regeneration(topic_id)
    return unless (topic = Topic.find_by(id: topic_id))

    topic.generate_reply
    topic.save
  end
end
