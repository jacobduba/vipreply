# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :authorize_has_account

  def authorize_has_account
    account_id = session[:account_id]
    unless account_id
      redirect_to login_path
      return
    end

    @account = Account.find(account_id)
  end
end
