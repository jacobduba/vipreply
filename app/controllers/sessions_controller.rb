# frozen_string_literal: true

require "google/apis/gmail_v1"
require "date"

class SessionsController < ApplicationController
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
      Rails.logger.error e.message
      redirect_to "/login", alert: "Failed to link your Gmail account."
      return
    end

    # Create inbox if it doesn't exist
    unless account.inbox
      account.create_inbox
      SetupInboxJob.perform_later account.inbox.id
      Rails.logger.info "Inbox setup done for #{account.email}."
    end

    # TODO MOVE THIS TO A JOB
    account.setup_gmail_watch

    session[:account_id] = account.id
    redirect_to root_path
  end

  private

  def login_params
    params.permit(:refresh_token_expired)
  end
end
