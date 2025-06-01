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

  def omniauth
    auth = request.env["omniauth.auth"]
    provider = params[:provider]

    # Debug - log the auth hash details
    Rails.logger.info "AUTH HASH: #{auth.inspect}" # [cite: 69]
    Rails.logger.info "PROVIDER: #{provider}" # [cite: 69]

    if auth.nil?
      Rails.logger.error "Auth hash is nil for provider: #{provider}" # [cite: 70]
      redirect_to login_path, alert: "Authentication failed. No auth data received."
      return # [cite: 71]
    end

    # Ensure we have the info and credentials we need
    if auth.info.nil?
      Rails.logger.error "Auth info is nil for provider: #{provider}" # [cite: 72]
      redirect_to login_path, alert: "Authentication failed. Missing user info."
      return # [cite: 73]
    end

    if auth.credentials.nil?
      Rails.logger.error "Auth credentials are nil for provider: #{provider}" # [cite: 74]
      redirect_to login_path, alert: "Authentication failed. Missing credentials."
      return # [cite: 75]
    end

    # Check for required fields in auth.info
    if auth.info.email.blank?
      Rails.logger.error "Auth email is missing for provider: #{provider}" # [cite: 76]
      redirect_to login_path, alert: "Authentication failed. Email not provided."
      return # [cite: 77]
    end

    begin
      case provider
      when "google_oauth2"
        handle_google_oauth_callback(auth)
      when "microsoft_office365"
        handle_microsoft_oauth_callback(auth)
      else
        Rails.logger.error "Unsupported provider: #{provider}"
        redirect_to login_path, alert: "Authentication provider not supported."
      end # [cite: 78]
    rescue => e
      Rails.logger.error "Error during auth callback: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      redirect_to login_path, alert: "Authentication error: #{e.message}"
    end
  end

  private

  # Microsoft OAuth callback handler
  def handle_microsoft_oauth_callback(auth_hash)
    Rails.logger.info "Processing Microsoft OAuth callback"
    Rails.logger.info "Email: #{auth_hash.info.email}"

    # Log the token information
    Rails.logger.info "Access token present: #{auth_hash.credentials.token.present?}"
    Rails.logger.info "Refresh token present: #{auth_hash.credentials.refresh_token.present?}"
    Rails.logger.info "Expires at: #{auth_hash.credentials.expires_at}"

    # TODO: For both here and in google, we want to instead be storing and searching account by provider-id or some similar field. Look in Jacob discord dms for more info [cite: 79]
    # Current implementation: Account is central, identified by email. Inboxes are provider-specific connections to this Account.
    # Ideal future state for robustly handling provider identities (e.g., if user's email changes at provider):
    # 1. An `Inbox` model should store `provider_uid` (e.g., `auth_hash.uid`).
    # 2. Lookup strategy:
    #    a. Try to find `Inbox` by `(provider, provider_uid)`.
    #    b. If found, `account = inbox.account`. Update this account's emails/details if necessary from `auth_hash.info`.
    #    c. If `Inbox` not found:
    #        i. If a user is already logged in (`session[:account_id]`), use that `Account`. Create new `Inbox` for this account, provider, and `provider_uid`.
    #        ii. Else, try to find an `Account` by `auth_hash.info.email` (primary or secondary).
    #            - If `Account` found, use it. Create new `Inbox` for this account, provider, `provider_uid`.
    #            - If `Account` not found, create a new `Account` from `auth_hash.info`. Then create the new `Inbox`.
    # This requires schema changes (adding `provider_uid` to `inboxes` table).
    # The current code below uses email-based Account lookup and then provider-based Inbox lookup within that Account.

    # Find or create the account
    existing_account = if session[:account_id]
      Account.find_by(id: session[:account_id])
    else
      # First try to find by primary email
      auth_email = auth_hash.info.email.downcase.strip
      account = Account.find_by(email: auth_email)

      # If not found, check if any account has this as a secondary email
      if account.nil?
        account = Account.where("secondary_emails @> ARRAY[?]::varchar[]", [auth_email]).first # [cite: 81]
      end # [cite: 80]

      account
    end

    if existing_account.nil?
      Rails.logger.info "Creating new account for #{auth_hash.info.email}" # [cite: 82]
      existing_account = Account.new(email: auth_hash.info.email)
      existing_account.name = auth_hash.info.name
      existing_account.first_name = auth_hash.info.first_name || auth_hash.info.name.split(" ").first # [cite: 83]
      existing_account.last_name = auth_hash.info.last_name || auth_hash.info.name.split(" ")[1..-1]&.join(" ") # [cite: 84]
      existing_account.image_url = auth_hash.info.image
      existing_account.save!
    else # [cite: 85]
      Rails.logger.info "Found existing account: #{existing_account.id}"
      # Add as secondary email if needed
      if existing_account.email != auth_hash.info.email && !existing_account.owns_email?(auth_hash.info.email)
        Rails.logger.info "Adding secondary email: #{auth_hash.info.email}"
        secondary_emails = existing_account.secondary_emails || [] # [cite: 86]
        secondary_emails << auth_hash.info.email
        existing_account.update(secondary_emails: secondary_emails)
      end
    end

    # Find or create inbox
    inbox = existing_account.inboxes.find_or_initialize_by(provider: "microsoft_office365")
    # Ideally, this would also use auth_hash.uid if Inbox model stored it:
    # inbox = Inbox.find_or_initialize_by(provider: "microsoft_office365", provider_uid: auth_hash.uid)
    # And then associate with `existing_account` if new.

    # Log inbox details
    Rails.logger.info "Inbox: #{inbox.new_record? ? "New" : "Existing"}"
    Rails.logger.info "Current refresh token: #{inbox.refresh_token.present? ? "Present" : "Missing"}"

    # Update inbox
    inbox.access_token = auth_hash.credentials.token

    if auth_hash.credentials.refresh_token.present?
      Rails.logger.info "Updating refresh token" # [cite: 87]
      inbox.refresh_token = auth_hash.credentials.refresh_token
    elsif inbox.refresh_token.blank?
      Rails.logger.warn "No refresh token provided by Microsoft and none saved" # [cite: 88]
      session[:account_id] = existing_account.id # Save account_id for the consent redirect
      # Store necessary auth_hash info in session to complete inbox creation after consent
      session[:pending_auth_info] = {
        provider: "microsoft_office365",
        uid: auth_hash.uid, # Store UID
        email: auth_hash.info.email,
        name: auth_hash.info.name,
        first_name: auth_hash.info.first_name,
        last_name: auth_hash.info.last_name,
        image_url: auth_hash.info.image,
        access_token: auth_hash.credentials.token,
        expires_at: auth_hash.credentials.expires_at
      }
      redirect_to "/auth/microsoft_office365?prompt=consent"
      return
    end

    inbox.expires_at = if auth_hash.credentials.expires_at.present?
      Time.at(auth_hash.credentials.expires_at) # [cite: 89]
    else
      # Microsoft tokens usually expire in 1 hour if not specified
      1.hour.from_now
    end

    # Save the inbox
    begin
      inbox.save!
      Rails.logger.info "Successfully saved Microsoft inbox" # [cite: 90]
    rescue => e
      Rails.logger.error "Failed to save inbox: #{e.message}"
      redirect_to login_path, alert: "Failed to link your Outlook account."
      return # [cite: 91]
    end

    # Set up session
    session[:account_id] = existing_account.id
    session[:inbox_id] = inbox.id
    session.delete(:pending_auth_info) # Clear pending auth info

    # Initialize inbox if needed
    if inbox.topics.empty?
      Rails.logger.info "Scheduling inbox setup job" # [cite: 92]
      SetupInboxJob.perform_later(inbox.id)
    end

    # Redirect to inbox
    redirect_to root_path
  end

  # Google OAuth callback handler
  def handle_google_oauth_callback(auth_hash)
    if auth_hash.nil?
      Rails.logger.error "Auth hash is nil for Google OAuth" # [cite: 93]
      redirect_to login_path, alert: "Authentication failed."
      return # [cite: 94]
    end

    # Debug info
    Rails.logger.info "Auth credentials: access_token present: #{auth_hash.credentials.token.present?}, " +
      "refresh_token present: #{auth_hash.credentials.refresh_token.present?}, " +
      "expires_at: #{auth_hash.credentials.expires_at}"

    # See TODO in handle_microsoft_oauth_callback for ideal provider_uid handling.
    # Current implementation: Account is central, identified by email. Inboxes are provider-specific connections.

    # First check if we're already logged in
    # If so, we're trying to add a new provider to the existing account
    existing_account = nil
    if session[:account_id]
      existing_account = Account.find_by(id: session[:account_id])
    end

    # If we're not logged in, or we can't find the account in session
    if existing_account.nil? # [cite: 95]
      # Try to find an account by the email from the auth provider
      auth_email = auth_hash.info.email.downcase.strip

      # Find any account that has this email (either primary or secondary)
      existing_account = Account.find_by(email: auth_email)

      # If not found, check if any account has this as a secondary email
      if existing_account.nil?
        existing_account = Account.where("secondary_emails @> ARRAY[?]::varchar[]", [auth_email]).first # [cite: 96]
      end
    end

    # Create a new account if needed
    if existing_account.nil?
      existing_account = Account.new(email: auth_hash.info.email) # [cite: 97]
      existing_account.name = auth_hash.info.name
      existing_account.first_name = auth_hash.info.first_name || auth_hash.info.name.split(" ").first # [cite: 98]
      existing_account.last_name = auth_hash.info.last_name || auth_hash.info.name.split(" ")[1..-1]&.join(" ") # [cite: 99]
      existing_account.image_url = auth_hash.info.image
      existing_account.save!
      Rails.logger.info "Created new account for #{auth_hash.info.email}" # [cite: 100]
    else
      Rails.logger.info "Found existing account: #{existing_account.id} for email: #{auth_hash.info.email}"

      # If this is a different email from what we know, add it as secondary
      if existing_account.email != auth_hash.info.email && !existing_account.owns_email?(auth_hash.info.email)
        Rails.logger.info "Adding secondary email: #{auth_hash.info.email}"
        secondary_emails = existing_account.secondary_emails || [] # [cite: 101]
        secondary_emails << auth_hash.info.email
        existing_account.update(secondary_emails: secondary_emails)
      end

      # Update profile image if needed
      if existing_account.image_url.blank? && auth_hash.info.image.present? # [cite: 102]
        existing_account.update(image_url: auth_hash.info.image)
      end
    end

    # Find existing inbox for this provider or create a new one
    inbox = existing_account.inboxes.find_or_initialize_by(provider: "google_oauth2")
    # Ideally, this would also use auth_hash.uid if Inbox model stored it.

    # Always update the access token
    inbox.access_token = auth_hash.credentials.token

    # Set expiration time
    if auth_hash.credentials.expires_at.present?
      inbox.expires_at = Time.at(auth_hash.credentials.expires_at) # [cite: 103]
    end

    # Only update refresh token if we received a new one
    if auth_hash.credentials.refresh_token.present?
      inbox.refresh_token = auth_hash.credentials.refresh_token # [cite: 104]
    end

    # If we still don't have a refresh token, we need to force consent
    if inbox.refresh_token.blank?
      Rails.logger.warn "No refresh token received and none saved. Redirecting to force consent." # [cite: 105]
      session[:account_id] = existing_account.id  # Save the account ID for the next attempt [cite: 106]
      # Store necessary auth_hash info in session to complete inbox creation after consent
      session[:pending_auth_info] = {
        provider: "google_oauth2",
        uid: auth_hash.uid, # Store UID
        email: auth_hash.info.email,
        name: auth_hash.info.name,
        first_name: auth_hash.info.first_name,
        last_name: auth_hash.info.last_name,
        image_url: auth_hash.info.image,
        access_token: auth_hash.credentials.token,
        expires_at: auth_hash.credentials.expires_at
      }
      redirect_to "/auth/google_oauth2?prompt=consent&access_type=offline"
      return
    end

    begin
      inbox.save!
      Rails.logger.info "Successfully saved inbox with refresh token." # [cite: 107]
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save inbox: #{e.message}"
      redirect_to "/login", alert: "Failed to link your email account."
      return # [cite: 108]
    end

    # Set up session
    session[:account_id] = existing_account.id
    session[:inbox_id] = inbox.id
    session.delete(:pending_auth_info) # Clear pending auth info

    # Initialize inbox if needed
    if inbox.topics.empty?
      SetupInboxJob.perform_later(inbox.id) # [cite: 109]
    end

    # Always redirect to root_path after successful authentication
    redirect_to root_path
  end
end