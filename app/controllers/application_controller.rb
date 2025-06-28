# frozen_string_literal: true

class ApplicationController < ActionController::Base
  rescue_from Signet::AuthorizationError do |e|
    # Invalid/revoked refresh token - need full re-auth
    reset_session
    flash[:alert] = "Your Google connection expired. Try logging in again."
    flash[:prompt_consent] = true
    redirect_to login_path
  end

  rescue_from Account::NoGmailPermissionsError do |e|
    redirect_to upgrade_permissions_path
  end

  def authorize_account
    account_id = session[:account_id]

    unless account_id
      return redirect_to root_path
    end

    begin
      @account = Account.find account_id
    rescue ActiveRecord::RecordNotFound
      reset_session
      return redirect_to root_path
    end

    Honeybadger.context({
      account: @account
    })
  end

  def require_subscription
    unless @account.subscribed?
      redirect_to inbox_path
    end
  end
  
  def require_gmail_permissions
    redirect_to upgrade_permissions_path unless @account.has_gmail_permissions
  end
end
