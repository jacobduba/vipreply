# frozen_string_literal: true

class AnalyticsController < ApplicationController
  http_basic_authenticate_with(
    name: Rails.application.credentials.dig(:analytics, :http_basic_auth_user),
    password: Rails.application.credentials.dig(:analytics, :http_basic_auth_password)
  )

  def index
    @accounts = Account
      .select(:id, :name, :created_at, :last_active_at, :session_count)
      .order(created_at: :desc)
  end
end
