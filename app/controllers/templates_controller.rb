# frozen_string_literal: true

# app/controllers/templates_controller.rb
class TemplatesController < ApplicationController
  include GeneratorConcern

  before_action :authorize_account
  before_action :require_subscription
  before_action :set_template, only: [:edit, :update, :destroy]
  before_action :authorize_account_owns_template, only: [:edit, :update, :destroy]

  def index
    @templates = @account.inbox.templates.order(id: :asc)
  end

  def new
    @template = Template.new
    @input_errors = []
    @output_errors = []
    @topic_id = params[:topic_id]
  end

  def create
    @template = @account.inbox.templates.new(template_params)
    topic_id = params[:template][:topic_id]

    unless @template.save
      @input_errors = @template.errors.full_messages_for(:input)
      @output_errors = @template.errors.full_messages_for(:output)
      render :new
    end

    render turbo_stream: turbo_stream.append("templates_collection", partial: "template", locals: {template: @template})
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

  def authorize_account_owns_template
    unless @template.inbox.account == @account
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
  end

  def template_params
    params.require(:template).permit(:input, :output)
  end
end
