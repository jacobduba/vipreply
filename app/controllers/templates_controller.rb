# frozen_string_literal: true

# app/controllers/templates_controller.rb
class TemplatesController < ApplicationController
  include GeneratorConcern

  before_action :authorize_account
  before_action :set_template, only: [:edit, :update, :destroy]
  before_action :require_subscription

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

    unless @template.save
      @input_errors = @template.errors.full_messages_for(:input)
      @output_errors = @template.errors.full_messages_for(:output)
      render :new
    end

    if regenerate
      handle_regeneration topic_id
    else
      render turbo_stream: turbo_stream.append("templates_collection", partial: "template", locals: {template: @template})
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

    render turbo_stream: [
      turbo_stream.replace(@template, partial: "template", locals: {template: @template}),
      turbo_stream.remove("edit-template-modal")
    ]
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
