class MarketingController < ApplicationController
  skip_before_action :authorize_account

  def landing
    if session[:account_id]
      redirect_to inbox_path
    end
  end

  def privacy
  end
end
