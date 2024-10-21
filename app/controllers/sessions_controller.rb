class SessionsController < ApplicationController
  skip_before_action :authorize_has_account

  def new
    if session[:account_id]
      redirect_to root_path
    end

    @account = Account.new
    render 'login'
  end

  def create
    params_n = login_params

    @username = params_n[:username]

    @account = Account.find_by(username: @password)

    if @account && @account.authenticate(params_n[:password])
      session[:account_id] = @account.id
      redirect_to root_path
    else
      flash[:alert] = "Username or password is invalid."
      redirect_to login_path
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
