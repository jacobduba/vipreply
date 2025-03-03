# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authorize_account

  def authorize_account
    account_id = session[:account_id]
    inbox_id = session[:inbox_id]

    unless account_id
      return redirect_to login_path
    end

    begin
      @account = Account.find(account_id)
      @inbox = inbox_id ? Inbox.find(inbox_id) : @account.inboxes.first
    rescue ActiveRecord::RecordNotFound
      reset_session
      return redirect_to login_path
    end

    unless @inbox&.refresh_token
      reset_session
      flash[:prompt_consent] = true
      return redirect_to login_path
    end

    return unless @inbox.expires_at < Time.current + 10.seconds

    begin
      @inbox.refresh_token!
    rescue => e
      Rails.logger.error "Token refresh failed: #{e.message}"
      reset_session
      flash[:prompt_consent] = true
      redirect_to login_path
    end
  end
end
