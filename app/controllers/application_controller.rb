# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :authorize_account

  def authorize_account
    account_id = session[:account_id]
    unless account_id
      return redirect_to login_path
    end

    begin
      @account = Account.find account_id
    rescue ActiveRecord::RecordNotFound
      reset_session
      return redirect_to login_path
    end

    Honeybadger.context({
      account: @account
    })

    if @account.refresh_token.nil?
      Rails.logger.debug "No refresh token found for #{@account.email}"
      reset_session
      flash[:prompt_consent] = true
      return redirect_to login_path
    end

    return unless @account.expires_at < Time.current + 10.seconds

    Rails.logger.debug "Access token expired for #{@account.email}, attempting refresh."

    begin
      @account.refresh_google_token!
    rescue Signet::AuthorizationError => e
      Rails.logger.debug "Refresh token is invalid for #{@account.email} with error: #{e.message}"
      reset_session
      flash[:prompt_consent] = true
      redirect_to login_path
    end
  end
end
