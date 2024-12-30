class InboxesController < ApplicationController
  def index
    @inbox = @account.inbox
    @to_do_topics = @inbox.topics.where(do_not_reply: false).order(date: :asc)
    @done_topics = @inbox.topics.where(do_not_reply: true).order(date: :desc)
  end
end
