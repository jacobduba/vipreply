class InboxesController < ApplicationController
  def index
    unless @inbox.present?
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
      return
    end

    selected_fields = [:id, :snippet, :date, :subject, :from, :to, :status, :message_count]
    @needs_reply_topics = @inbox.topics.not_spam.select(selected_fields).where(status: :needs_reply).order(date: :asc)
    @has_reply_topics = @inbox.topics.not_spam.select(selected_fields).where(status: :has_reply).order(date: :desc)

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
