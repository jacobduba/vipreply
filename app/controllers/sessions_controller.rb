class SessionsController < ApplicationController
  skip_before_action :authorize_has_account

  def new
    if session[:account_id]
      redirect_to root_path
    end

    @account = Account.new
  end

  def create
    params_n = login_params

    @account = Account.find_by(username: params_n[:username])

    if @account && @account.authenticate(params_n[:password])
      session[:account_id] = @account.id
      redirect_to root_path
    else
      flash[:alert] = "Login failed"
    end
  end

  def destroy
    reset_session
    redirect_to login_path
  end

  def login_params
    params.require(:account).permit(:username, :password)
  end
end
