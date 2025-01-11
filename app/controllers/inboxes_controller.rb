class InboxesController < ApplicationController
  include InboxManagementConcern
  def index
    @inbox = @account.inbox
    @to_do_topics = @inbox.topics.where(do_not_reply: false).order(date: :asc)
    @done_topics = @inbox.topics.where(do_not_reply: true).order(date: :desc)
  end

  def update
    inbox = @account.inbox

    if inbox.present?
      update_from_history(inbox)
      flash[:notice] = "Inbox updated successfully!"
    else
      flash[:alert] = "Failed to update inbox."
    end

    redirect_to root_path
  end
end
