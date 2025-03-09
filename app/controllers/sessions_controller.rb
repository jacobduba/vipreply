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

  # Insert this debug helper at the top of the SessionsController class
  def omniauth
    auth = request.env["omniauth.auth"]
    provider = params[:provider]

    # Debug - log the auth hash details
    Rails.logger.info "AUTH HASH: #{auth.inspect}"
    Rails.logger.info "PROVIDER: #{provider}"

    if auth.nil?
      Rails.logger.error "Auth hash is nil for provider: #{provider}"
      redirect_to login_path, alert: "Authentication failed. No auth data received."
      return
    end

    # Ensure we have the info and credentials we need
    if auth.info.nil?
      Rails.logger.error "Auth info is nil for provider: #{provider}"
      redirect_to login_path, alert: "Authentication failed. Missing user info."
      return
    end

    if auth.credentials.nil?
      Rails.logger.error "Auth credentials are nil for provider: #{provider}"
      redirect_to login_path, alert: "Authentication failed. Missing credentials."
      return
    end

    # Check for required fields in auth.info
    if auth.info.email.blank?
      Rails.logger.error "Auth email is missing for provider: #{provider}"
      redirect_to login_path, alert: "Authentication failed. Email not provided."
      return
    end

    begin
      case provider
      when "google_oauth2"
        handle_oauth_callback(auth, provider)
      when "microsoft_office365"
        handle_microsoft_oauth_callback(auth)
      else
        Rails.logger.error "Unsupported provider: #{provider}"
        redirect_to login_path, alert: "Authentication provider not supported."
      end
    rescue => e
      Rails.logger.error "Error during auth callback: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      redirect_to login_path, alert: "Authentication error: #{e.message}"
    end
  end

  # Add a specific method for Microsoft authentication
  def handle_microsoft_oauth_callback(auth_hash)
    Rails.logger.info "Processing Microsoft OAuth callback"
    Rails.logger.info "Email: #{auth_hash.info.email}"

    # Log the token information
    Rails.logger.info "Access token present: #{auth_hash.credentials.token.present?}"
    Rails.logger.info "Refresh token present: #{auth_hash.credentials.refresh_token.present?}"
    Rails.logger.info "Expires at: #{auth_hash.credentials.expires_at}"

    # Find or create the account
    existing_account = if session[:account_id]
      Account.find_by(id: session[:account_id])
    else
      Account.find_by(email: auth_hash.info.email)
    end

    if existing_account.nil?
      Rails.logger.info "Creating new account for #{auth_hash.info.email}"
      existing_account = Account.new(email: auth_hash.info.email)
      existing_account.name = auth_hash.info.name
      existing_account.first_name = auth_hash.info.first_name || auth_hash.info.name.split(" ").first
      existing_account.last_name = auth_hash.info.last_name || auth_hash.info.name.split(" ")[1..-1]&.join(" ")
      existing_account.image_url = auth_hash.info.image
      existing_account.save!
    else
      Rails.logger.info "Found existing account: #{existing_account.id}"
      # Add as secondary email if needed
      if existing_account.email != auth_hash.info.email && !existing_account.owns_email?(auth_hash.info.email)
        Rails.logger.info "Adding secondary email: #{auth_hash.info.email}"
        secondary_emails = existing_account.secondary_emails || []
        secondary_emails << auth_hash.info.email
        existing_account.update(secondary_emails: secondary_emails)
      end
    end

    # Find or create inbox
    inbox = existing_account.inboxes.find_or_initialize_by(provider: "microsoft_office365")

    # Log inbox details
    Rails.logger.info "Inbox: #{inbox.new_record? ? "New" : "Existing"}"
    Rails.logger.info "Current refresh token: #{inbox.refresh_token.present? ? "Present" : "Missing"}"

    # Update inbox
    inbox.access_token = auth_hash.credentials.token

    if auth_hash.credentials.refresh_token.present?
      Rails.logger.info "Updating refresh token"
      inbox.refresh_token = auth_hash.credentials.refresh_token
    elsif inbox.refresh_token.blank?
      Rails.logger.warn "No refresh token provided by Microsoft and none saved"
      session[:account_id] = existing_account.id
      redirect_to "/auth/microsoft_office365?prompt=consent"
      return
    end

    inbox.expires_at = if auth_hash.credentials.expires_at.present?
      Time.at(auth_hash.credentials.expires_at)
    else
      # Microsoft tokens usually expire in 1 hour if not specified
      1.hour.from_now
    end

    # Save the inbox
    begin
      inbox.save!
      Rails.logger.info "Successfully saved Microsoft inbox"
    rescue => e
      Rails.logger.error "Failed to save inbox: #{e.message}"
      redirect_to login_path, alert: "Failed to link your Outlook account."
      return
    end

    # Set up session
    session[:account_id] = existing_account.id
    session[:inbox_id] = inbox.id

    # Initialize inbox if needed
    if inbox.topics.empty?
      Rails.logger.info "Scheduling inbox setup job"
      SetupInboxJob.perform_later(inbox.id)
    end

    # Redirect to inbox
    redirect_to root_path
  end

  private

  # Update this method in SessionsController
  def handle_oauth_callback(auth_hash, provider)
    if auth_hash.nil?
      Rails.logger.error "Auth hash is nil for provider: #{provider}"
      redirect_to login_path, alert: "Authentication failed."
      return
    end

    # Debug info
    Rails.logger.info "Auth credentials: access_token present: #{auth_hash.credentials.token.present?}, " +
      "refresh_token present: #{auth_hash.credentials.refresh_token.present?}, " +
      "expires_at: #{auth_hash.credentials.expires_at}"

    # First check if we're already logged in
    # If so, we're trying to add a new provider to the existing account
    if session[:account_id]
      existing_account = Account.find_by(id: session[:account_id])
    end

    # If we're not logged in, or we can't find the account in session
    if existing_account.nil?
      # Try to find an account by the email from the auth provider
      auth_email = auth_hash.info.email.downcase.strip

      # Find any account that has this email (either primary or secondary)
      existing_account = Account.find_by(email: auth_email)

      # If not found, check if any account has this as a secondary email
      if existing_account.nil?
        existing_account = Account.where("secondary_emails @> ARRAY[?]::varchar[]", [auth_email]).first
      end
    end

    # Create a new account if needed
    if existing_account.nil?
      existing_account = Account.new(email: auth_hash.info.email)
      existing_account.name = auth_hash.info.name
      existing_account.first_name = auth_hash.info.first_name || auth_hash.info.name.split(" ").first
      existing_account.last_name = auth_hash.info.last_name || auth_hash.info.name.split(" ")[1..-1]&.join(" ")
      existing_account.image_url = auth_hash.info.image
      existing_account.save!
      Rails.logger.info "Created new account for #{auth_hash.info.email}"
    else
      Rails.logger.info "Found existing account: #{existing_account.id} for email: #{auth_hash.info.email}"

      # If this is a different email from what we know, add it as secondary
      if existing_account.email != auth_hash.info.email && !existing_account.owns_email?(auth_hash.info.email)
        Rails.logger.info "Adding secondary email: #{auth_hash.info.email}"
        secondary_emails = existing_account.secondary_emails || []
        secondary_emails << auth_hash.info.email
        existing_account.update(secondary_emails: secondary_emails)
      end

      # Update profile image if needed
      if existing_account.image_url.blank? && auth_hash.info.image.present?
        existing_account.update(image_url: auth_hash.info.image)
      end
    end

    # Find existing inbox for this provider or create a new one
    inbox = existing_account.inboxes.find_or_initialize_by(provider: provider)

    # Always update the access token
    inbox.access_token = auth_hash.credentials.token

    # Set expiration time
    if auth_hash.credentials.expires_at.present?
      inbox.expires_at = Time.at(auth_hash.credentials.expires_at)
    end

    # Only update refresh token if we received a new one
    if auth_hash.credentials.refresh_token.present?
      inbox.refresh_token = auth_hash.credentials.refresh_token
    end

    # If we still don't have a refresh token, we need to force consent
    if inbox.refresh_token.blank?
      Rails.logger.warn "No refresh token received and none saved. Redirecting to force consent."
      session[:account_id] = existing_account.id  # Save the account ID for the next attempt
      redirect_to (provider == "google_oauth2") ?
        "/auth/google_oauth2?prompt=consent&access_type=offline" :
        "/auth/microsoft_office365?prompt=consent"
      return
    end

    begin
      inbox.save!
      Rails.logger.info "Successfully saved inbox with refresh token."
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save inbox: #{e.message}"
      redirect_to "/login", alert: "Failed to link your email account."
      return
    end

    # Set up session
    session[:account_id] = existing_account.id
    session[:inbox_id] = inbox.id

    # Initialize inbox if needed
    if inbox.topics.empty?
      SetupInboxJob.perform_later(inbox.id)
    end

    # Always redirect to root_path after successful authentication
    redirect_to root_path
  end
end
