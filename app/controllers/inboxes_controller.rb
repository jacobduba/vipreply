class InboxesController < ApplicationController
  def index
    @inboxes = @account.inboxes

    @no_inboxes = @inboxes.empty?
  end
end
