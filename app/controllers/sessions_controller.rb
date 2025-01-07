# frozen_string_literal: true

require "google/apis/gmail_v1"
require "date"

class SessionsController < ApplicationController
  include InboxSetupConcern
  skip_before_action :authorize_has_account

  def new
    redirect_to root_path if session[:account_id]

    permitted_params = login_params

    refresh_token_expired = permitted_params["refresh_token_expired"]

    # we set refresh_token_expired when refresh token fails to get new refresh token
    @oauth_url = if refresh_token_expired
      "/auth/google_oauth2?prompt=consent"
    else
      "/auth/google_oauth2"
    end
  end

  def destroy
    reset_session
    redirect_to login_path
  end

  def googleAuth
    # https://github.com/zquestz/omniauth-google-oauth2?tab=readme-ov-file#auth-hash
    auth_hash = request.env["omniauth.auth"]

    account = Account.find_by(provider: auth_hash.provider, uid: auth_hash.uid)

    account ||= Account.new

    account.provider = auth_hash.provider # google_oauth2
    account.uid = auth_hash.uid
    account.access_token = auth_hash.credentials.token
    # Refresh tokens are only given when the user consents (typically the first time) thus ||=
    account.refresh_token ||= auth_hash.credentials.refresh_token
    account.expires_at = Time.at(auth_hash.credentials.expires_at)
    account.email = auth_hash.info.email
    account.name = auth_hash.info.name
    account.first_name = auth_hash.info.first_name
    account.last_name = auth_hash.info.last_name

    begin
      account.save!
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error e
      redirect_to "/login"
    end

    # Supposed to only setup inbox if not setup...
    # unless account.inbox
    #   setup_inbox account
    # end

    # ... but for testing delete inbox and setup every time
    account&.inbox&.destroy
    setup_inbox account

    session[:account_id] = account.id
    redirect_to root_path
  end

  private

  def login_params
    params.permit(:refresh_token_expired)
  end
end
