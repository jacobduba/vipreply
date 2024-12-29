class InboxesController < ApplicationController
  def index
    @inbox = @account.inbox
    @topics = @inbox.topics
  end
end
