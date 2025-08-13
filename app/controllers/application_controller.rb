# frozen_string_literal: true

class ApplicationController < ActionController::Base
  after_action :track_daily_activity

  rescue_from Account::NoGmailPermissionsError do |e|
    flash[:alert] = "Please connect your Gmail account to continue."
    redirect_to upgrade_permissions_path
  end

  def authorize_account
    account_id = session[:account_id]

    unless account_id
      return redirect_to root_path
    end

    begin
      @account = Account.find account_id
    rescue ActiveRecord::RecordNotFound
      reset_session
      return redirect_to root_path
    end

    Honeybadger.context({account: @account})
  end

  def require_subscription
    unless @account.has_access?
      redirect_to inbox_path
    end
  end

  def require_gmail_permissions
    redirect_to upgrade_permissions_path unless @account.has_gmail_permissions
  end

  private

  def track_daily_activity
    return unless @account&.persisted?

    time = Time.current

    @account.session_count += 1 if @account.last_active_at + 30.minutes < time
    @account.last_active_at = Time.current

    @account.save!
  end
end
