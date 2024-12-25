# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :authorize_has_account

  def new
    redirect_to root_path if session[:account_id]

    @account = Account.new
  end

  def create
    params_n = login_params

    @account = Account.find_by(username: params_n[:username])

    if @account&.authenticate(params_n[:password])
      session[:account_id] = @account.id
      redirect_to root_path
    else
      @invalid_username_or_password = true
      @username = params_n[:username]
      @account = Account.new

      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path
  end

  def googleAuth
    # https://github.com/zquestz/omniauth-google-oauth2?tab=readme-ov-file#auth-hash
    user_info = request.env["omniauth.auth"]

    account = Account.find_by(provider: "google_oauth2", uid: user_info.credentials)

    unless account
      account.
      session[:account_id] = @account.id
      redirect_to "/inbox"
      return
    end

    @account.update(account_token: user_info.credentials.token, refresh_token: user_info.credentials.refresh_token)

    redirect "/inbox"
  end

  private

  def login_params
    params.require(:account).permit(:username, :password)
  end
end
