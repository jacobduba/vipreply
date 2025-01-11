class TopicsController < ApplicationController
  before_action :set_topic
  before_action :authorize_account_owns_topic

  include GeneratorConcern

  def show
    @messages = @topic.messages.order(date: :asc)

    # iframes are used to isolate email code
    # Why??? I do not trust myself to securely sanitize emails
    # Yes. this makes the user experience worse
    # More: https://security.stackexchange.com/a/134587

    @template = @topic.template
    @generated_reply = @topic.generated_reply
  end

  def regenerate_reply
    handle_regenerate_reply(params[:id])
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
