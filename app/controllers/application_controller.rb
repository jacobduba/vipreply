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
    # TODO: redirect to kind oauth screen once created
    redirect_to login_path, alert: "Please grant email permissions to continue."
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

  REQUIRED_SCOPES = ["https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.send",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/userinfo.profile",
    "openid"]

  def contains_all_oauth_scopes?(scopes)
    scopes = scopes.split(" ")
    # & is intersection
    # to find what subset of scopes is in REQUIRED_SCOPES
    intersection = scopes & REQUIRED_SCOPES
    # order matters in array equality
    # that's why i convert to sets to remove order
    intersection.to_set == REQUIRED_SCOPES.to_set
  end

  def require_subscription
    unless @account.subscribed?
      redirect_to inbox_path
    end
  end
end
