# frozen_string_literal: true

# app/controllers/templates_controller.rb
class TemplatesController < ApplicationController
  include GeneratorConcern

  before_action :authorize_account
  before_action :require_gmail_permissions
  before_action :require_subscription
  before_action :set_template, only: [ :edit, :update, :destroy, :enable_auto_reply, :disable_auto_reply ]
  before_action :authorize_account_owns_template, only: [ :edit, :update, :destroy, :enable_auto_reply, :disable_auto_reply ]

  def index
    @templates = @account.inbox.templates.order(id: :asc)
  end

  def new
    @template = Template.new
    @output_errors = []
  end

  def create
    @template = @account.inbox.templates.new(template_params)

    unless @template.save
      @output_errors = @template.errors.full_messages_for(:output)
      render :new
      return
    end

    render turbo_stream: turbo_stream.append("templates_collection", partial: "template", locals: { template: @template })
  end

  def edit
    @output_errors = []
  end

  def update
    unless @template.update(template_params)
      @output_errors = @template.errors.full_messages_for(:output)
      render :edit
      return
    end

    render turbo_stream: [
      turbo_stream.replace(@template, partial: "template", locals: { template: @template }),
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

  def enable_auto_reply
    update_auto_reply(true)
  end

  def disable_auto_reply
    update_auto_reply(false)
  end

  private

  def update_auto_reply(value)
    unless @template.update(auto_reply: value)
      head :unprocessable_entity
      return
    end

    render turbo_stream: turbo_stream.replace(
      view_context.dom_id(@template, :auto_reply_toggle),
      partial: "templates/auto_reply_toggle",
      locals: { template: @template }
    )
  end

  def set_template
    @template = Template.find(params[:id])
  end

  def authorize_account_owns_template
    unless @template.inbox.account == @account
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
  end

  def template_params
    params.require(:template).permit(:output)
  end
end
