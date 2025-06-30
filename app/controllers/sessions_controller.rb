# frozen_string_literal: true

class SessionsController < ApplicationController
  before_action :authorize_account, only: [:upgrade_permissions]

  def new
    redirect_to root_path if session[:account_id]
    @prompt_consent = flash[:prompt_consent] || false
  end

  def upgrade_permissions
    @display_name = @account.name || @account.email
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
    account.email = auth_hash.info.email
    account.name = auth_hash.info.name
    account.first_name = auth_hash.info.first_name
    account.last_name = auth_hash.info.last_name
    account.image_url = auth_hash.info.image

    # Note to future self that refresh token is only needed to access Gmail API
    # Login works fine without refresh token... so no gmail scopes, no need to store refresh token
    # That's why I decided not to logout and force prompt consent if refresh token is invalid or doesn't exist
    # Simply just show the users the kind oauth upgrade screen

    new_refresh_token = auth_hash.credentials.refresh_token.present?
    if new_refresh_token
      # Only update tokens when we get a new refresh token (new auth flow)

      # Only override access token when there's a new refresh token
      # Cuz no refresh token given when signing in without gmail scopes
      # And those scopes might be granted already
      account.access_token = auth_hash.credentials.token
      account.expires_at = Time.at(auth_hash.credentials.expires_at)
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
    elsif new_refresh_token && account.has_gmail_permissions && account.subscribed?
      # We lost refresh token and just got it back
      # gmail watch can't refresh without refresh token
      # so refresh now that we have it
      RestoreGmailPubsubJob.perform_later account.id
      # No gmail watch means inbox is possibly out of date
      UpdateFromHistoryJob.perform_later account.inbox.id
    end

    was_upgrading = session[:account_id].present? && session[:account_id] == account.id
    if was_upgrading && !account.has_gmail_permissions
      flash[:alert] = "Please approve both Gmail permissions to continue"
      redirect_to upgrade_permissions_path
      return
    end

    reset_session
    session[:account_id] = account.id

    if account.has_gmail_permissions
      redirect_to inbox_path
    else
      redirect_to upgrade_permissions_path
    end
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
