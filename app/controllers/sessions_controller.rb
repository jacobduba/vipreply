# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  skip_before_action :authorize_account

  def new
    redirect_to root_path if session[:account_id]

    # Google OAuth URL
    @oauth_url = if flash[:prompt_consent]
      "/auth/google_oauth2?prompt=consent"
    else
      "/auth/google_oauth2"
    end

    # Microsoft OAuth URL
    @microsoft_oauth_url = "/auth/microsoft_office365"
  end

  def destroy
    reset_session
    redirect_to login_path
  end

  def google_auth
    handle_oauth_callback(request.env["omniauth.auth"], "google_oauth2")
  end

  def microsoft_auth
    handle_oauth_callback(request.env["omniauth.auth"], "microsoft_office365")
  end

  private

  def handle_oauth_callback(auth_hash, provider)
    # Find or create account by email
    account = Account.find_or_initialize_by(email: auth_hash.info.email)

    # Update account info if it's new
    if account.new_record?
      # Only store user info, not provider info
      account.name = auth_hash.info.name
      account.first_name = auth_hash.info.first_name
      account.last_name = auth_hash.info.last_name
      account.image_url = auth_hash.info.image

      account.save!
    end

    # Find existing inbox for this provider or create a new one
    inbox = account.inboxes.find_or_initialize_by(provider: provider)

    # Update inbox with token info
    inbox.access_token = auth_hash.credentials.token

    if auth_hash.credentials.refresh_token.present?
      inbox.refresh_token = auth_hash.credentials.refresh_token
    end

    if auth_hash.credentials.expires_at.present?
      inbox.expires_at = Time.at(auth_hash.credentials.expires_at)
    end

    begin
      inbox.save!
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save inbox: #{e.message}"
      redirect_to "/login", alert: "Failed to link your email account."
      return
    end

    # Set up session
    session[:account_id] = account.id
    session[:inbox_id] = inbox.id

    # Initialize inbox if needed
    if inbox.topics.empty?
      SetupInboxJob.perform_later(inbox.id)
    end

    redirect_to root_path
  end
end
