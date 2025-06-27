# frozen_string_literal: true

class SessionsController < ApplicationController
  before_action :authorize_account, only: [:upgrade_permissions]

  def new
    redirect_to root_path if session[:account_id]
    @prompt_consent = flash[:prompt_consent] || false
  end

  def upgrade_permissions
    # Show the kind OAuth upgrade screen
  end

  def destroy
    reset_session
    redirect_to root_path
  end

  def google_auth
    # https://github.com/zquestz/omniauth-google-oauth2?tab=readme-ov-file#auth-hash
    auth_hash = request.env["omniauth.auth"]

    account = Account.find_by(provider: auth_hash.provider, uid: auth_hash.uid)

    account ||= Account.new

    account.provider = auth_hash.provider # google_oauth2
    account.uid = auth_hash.uid
    account.access_token = auth_hash.credentials.token
    account.expires_at = Time.at(auth_hash.credentials.expires_at)
    account.email = auth_hash.info.email
    account.name = auth_hash.info.name
    account.first_name = auth_hash.info.first_name
    account.last_name = auth_hash.info.last_name
    account.image_url = auth_hash.info.image

    # Note to future self that refresh token is only needed to access Gmail API
    # Login works fine without refresh token... so no gmail scopes, no need to store refresh token
    # That's why I decided not to logout and force prompt consent if refresh token is invalid or doesn't exist
    # Simply just show the users the kind oauth upgrade screen

    if auth_hash.credentials.refresh_token.present?
      account.refresh_token = auth_hash.credentials.refresh_token
      account.has_gmail_permissions = has_gmail_scopes?(auth_hash.credentials.scope)
    end

    begin
      account.save!
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error e.message
      flash[:alert] = "There was an error linking your Google account. Please try again."
      redirect_to login_path
      return
    end

    # Create inbox if it doesn't exist
    if account.inbox.nil?
      account.create_inbox
      # SetupInboxJob.perform_later account.inbox.id
    elsif new_refresh_token.present? && account.has_gmail_permissions && account.subscribed?
      # We lost refresh token and just got it back
      # gmail watch can't refresh without refresh token
      # so refresh now that we have it
      RestoreGmailPubsubJob.perform_later account.id
      # No gmail watch means inbox is possibly out of date
      UpdateFromHistoryJob.perform_later account.inbox.id
    end

    reset_session
    session[:account_id] = account.id
    redirect_to inbox_path
  end

  private

  def has_gmail_scopes?(scopes)
    gmail_scopes = ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]

    scopes = scopes.split(" ")
    # & is intersection
    # to find what subset of scopes is in gmail_scopes
    intersection = scopes & gmail_scopes
    # order matters in array equality
    # that's why i convert to sets to remove order
    intersection.to_set == gmail_scopes.to_set
  end
end
