# frozen_string_literal: true

class InboxesController < ApplicationController
  before_action :authorize_account
  before_action :require_gmail_permissions
  before_action :require_subscription

  def index
    @inbox = @account.inbox

    unless @inbox.present?
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
      return
    end

    selected_fields = %i[id snippet date subject from_email from_name to_email to_name status
      message_count]
    @requires_action_topics = @inbox.topics.not_spam.select(selected_fields).where(status: :requires_action).order(date: :asc)
    @no_action_needed_topics = @inbox.topics.not_spam.select(selected_fields).where(status: :no_action_needed_marked_by_user).order(date: :desc)

    @turbo_cache_control = true
  end

  def update
    inbox = @account.inbox

    if inbox.present?
      UpdateFromHistoryJob.perform_later inbox.id
      flash[:notice] = "Inbox updated successfully!"
    else
      flash[:alert] = "Failed to update inbox."
    end

    redirect_to root_path
  end
end
