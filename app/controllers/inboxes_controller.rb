class InboxesController < ApplicationController
  def index
    @inbox = @account.inbox

    selected_fields = [:id, :snippet, :date, :subject, :from, :to, :all_taken_care_of, :message_count]

    @to_do_topics = @inbox.topics.select(selected_fields).where(all_taken_care_of: false).order(date: :asc)
    @done_topics = @inbox.topics.select(selected_fields).where(all_taken_care_of: true).order(date: :desc)
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
