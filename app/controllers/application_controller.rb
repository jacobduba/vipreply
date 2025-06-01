# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authorize_account

  # Update to authorize_account method in app/controllers/application_controller.rb

  def authorize_account
    account_id = session[:account_id]
    inbox_id = session[:inbox_id]

    unless account_id
      return redirect_to login_path
    end

    begin
      @account = Account.find(account_id)

      # Ensure the account has inboxes
      if @account.inboxes.none?
        flash[:notice] = "Please connect an email account"
        return redirect_to login_path
      end

      # Find the selected inbox or default to first available
      @inbox = if inbox_id
        @account.inboxes.find_by(id: inbox_id) || @account.inboxes.first
      else
        @account.inboxes.first
      end

      # Update session with current inbox_id
      session[:inbox_id] = @inbox.id
    rescue ActiveRecord::RecordNotFound
      reset_session
      return redirect_to login_path
    end

    Honeybadger.context({
      account: @account
    })

    # Verify inbox has a refresh token
    unless @inbox.refresh_token.present?
      Rails.logger.error "Missing refresh token for inbox #{@inbox.id}"

      # Only reset the current inbox, not the entire session
      session[:inbox_id] = nil
      flash[:prompt_consent] = true

      # Try to find another valid inbox
      alternate_inbox = @account.inboxes.where.not(id: @inbox.id).where.not(refresh_token: nil).first

      if alternate_inbox
        session[:inbox_id] = alternate_inbox.id
        return redirect_to root_path
      else
        # No valid inboxes found, reset session
        reset_session
        return redirect_to login_path
      end
    end

    # Check if token needs refreshing
    return unless @inbox.expires_at && @inbox.expires_at < Time.current + 10.seconds

    begin
      @inbox.refresh_token!
      Rails.logger.info "Successfully refreshed token for inbox #{@inbox.id}"
    rescue => e
      Rails.logger.error "Token refresh failed for inbox #{@inbox.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace

      # Only reset the current inbox, not the entire session
      session[:inbox_id] = nil
      flash[:error] = "We couldn't access your #{@inbox.provider.titleize} account. Please reconnect."

      # Try to find another valid inbox
      alternate_inbox = @account.inboxes.where.not(id: @inbox.id).first

      if alternate_inbox
        session[:inbox_id] = alternate_inbox.id
        redirect_to root_path
      else
        # No valid inboxes found, reset session
        reset_session
        flash[:prompt_consent] = true
        redirect_to login_path
      end
    end
  end
end
