class ApplicationController < ActionController::Base
  # http_basic_authenticate_with name: "demo", password: "emails"
  before_action :authorize_has_account

  def authorize_has_account
    account_id = session[:account_id]
    unless account_id
      redirect_to login_path
      return
    end

    @account = Account.find(account_id)
  end

  def authorize_account_has_model
    id = params[:model_id] || params[:id]

    unless @account.models.exists?(id)
      render file: "#{Rails.root}/public/404.html", status: :not_found
      return
    end
    
    @model = Model.find(id)
  end


end
