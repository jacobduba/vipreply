class PubsubRefreshJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Do something later
    @account = Account.all
  end
end
