class InboxesController < ApplicationController
  def index
    @inbox = @account.inbox

    if @inbox.present?
      selected_fields = [:id, :snippet, :date, :subject, :from, :to, :status, :message_count]

      @needs_reply_topics = @inbox.topics.select(selected_fields).where(status: :needs_reply).order(date: :asc)
      @has_reply_topics = @inbox.topics.select(selected_fields).where(status: :has_reply).order(date: :desc)

      @turbo_cache_control = true
    end
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
