class InboxesController < ApplicationController
  def index
    @inbox = @account.inbox
  end
end
