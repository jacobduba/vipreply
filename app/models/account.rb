# frozen_string_literal: true

class Account < ApplicationRecord
  has_and_belongs_to_many :models
  has_one :inbox, dependent: :destroy
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: {scope: :provider}
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  encrypts :access_token
  encrypts :refresh_token

  # Will have to do this with auth
  def refresh_google_token!
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      refresh_token: refresh_token,
      scope: ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
    )

    credentials.refresh!

    update!(
      access_token: credentials.access_token,
      token_expiry: credentials.expires_at
    )
  end

  def google_credentials
    Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      refresh_token: refresh_token,
      access_token: access_token,
      expires_at: expires_at,
      scope: ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"]
    )
  end
end
