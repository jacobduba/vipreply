# frozen_string_literal: true

class ApplicationController < ActionController::Base
  after_action :track_daily_activity

  rescue_from Account::NoGmailPermissionsError do |_e|
    flash[:alert] = "Please connect your Gmail account to continue."
    redirect_to upgrade_permissions_path
  end

  def authorize_account
    account_id = session[:account_id]

    return redirect_to sign_in_path unless account_id

    begin
      @account = Account.find account_id
    rescue ActiveRecord::RecordNotFound
      reset_session
      return redirect_to sign_in_path
    end

    Rails.error.set_context(
      # Honeybadger needs user instead of account
      user_id: @account.id,
      user_email: @account.email
    )
  end

  def require_subscription
    return if @account.has_access?

    redirect_to checkout_plans_path
  end

  def require_gmail_permissions
    redirect_to upgrade_permissions_path unless @account.has_gmail_permissions
  end

  private

  def track_daily_activity
    return unless @account&.persisted?
    return if @account.provider == "mock"

    time = Time.current

    if @account.last_active_at + 30.minutes < time
      POSTHOG.capture({
        distinct_id: "user_#{@account.id}",
        event: "session_started"
      })
    end

    @account.save!
  end
end
