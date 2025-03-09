class InboxesController < ApplicationController
  def index
    # Get all provider types
    all_providers = ["google_oauth2", "microsoft_office365"]

    # Get which providers the user is connected to
    @connected_providers = @account.inboxes.pluck(:provider).uniq

    # Get selected provider filters or default to connected providers
    @selected_providers = params[:providers] || @connected_providers

    # Get inboxes based on selected providers
    @inboxes = @account.inboxes.where(provider: @selected_providers)

    if @inboxes.empty?
      # Only show error if they have no inboxes or trying to filter by providers they're not connected to
      if @account.inboxes.empty? || (@selected_providers - @connected_providers).empty?
        render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
        return
      end
    end

    # Get topics from all selected inboxes
    selected_fields = [:id, :snippet, :date, :subject, :from, :to, :status, :message_count, :inbox_id]

    # Initialize empty collections
    @needs_reply_topics = Topic.none
    @has_reply_topics = Topic.none

    @inboxes.each do |inbox|
      @needs_reply_topics = @needs_reply_topics.or(inbox.topics.not_spam.select(selected_fields).where(status: :needs_reply))
      @has_reply_topics = @has_reply_topics.or(inbox.topics.not_spam.select(selected_fields).where(status: :has_reply))
    end

    # Sort the combined topics
    @needs_reply_topics = @needs_reply_topics.order(date: :asc)
    @has_reply_topics = @has_reply_topics.order(date: :desc)

    @turbo_cache_control = true
  end

  def update
    # Update to handle multiple inboxes
    if params[:inbox_id]
      inbox = @account.inboxes.find(params[:inbox_id])
      UpdateFromHistoryJob.perform_later(inbox.id) if inbox.present?
    else
      @account.inboxes.each do |inbox|
        UpdateFromHistoryJob.perform_later(inbox.id)
      end
    end

    flash[:notice] = "Inbox update started successfully!"
    redirect_to root_path
  end
end
