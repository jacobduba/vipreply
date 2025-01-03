class TopicsController < ApplicationController
  before_action :set_topic, only: [:show]
  before_action :authorize_account_owns_topic, only: [:show]

  def show
    @messages = @topic.messages.order(date: :asc)

    # iframes are used to isolate email code
    # Why??? I do not trust myself to securely sanitize emails
    # Yes. this makes the user experience worse
    # More: https://security.stackexchange.com/a/134587
  end

  private

  def set_topic
    @topic = Topic.find(params[:id])
  end

  def authorize_account_owns_topic
    unless @topic.inbox.account == @account
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
  end
end
