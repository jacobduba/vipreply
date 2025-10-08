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

    @requires_action_topics = @inbox.get_topics_requires_action
    @no_action_needed_topics = @inbox.get_topics_no_action_required

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

    redirect_to inbox_path
  end
end
