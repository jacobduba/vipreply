# Configure OmniAuth for both GET and POST methods
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true

# Monkey patch the Microsoft Office 365 OmniAuth strategy to ensure it properly obtains refresh tokens
module OmniAuth
  module Strategies
    class MicrosoftOffice365
      option :authorize_params, {
        prompt: "consent",
        response_mode: "query"
      }

      option :token_params, {
        scope: "openid profile email offline_access https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/Mail.ReadWrite https://graph.microsoft.com/User.Read"
      }
    end
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.google_client_id,
    Rails.application.credentials.google_client_secret,
    {
      scope: "email, profile, https://www.googleapis.com/auth/gmail.modify",
      prompt: "consent",
      access_type: "offline",
      include_granted_scopes: true
    }

  provider :microsoft_office365,
    Rails.application.credentials.microsoft_client_id,
    Rails.application.credentials.microsoft_client_secret,
    {
      scope: "openid profile email offline_access https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/Mail.ReadWrite https://graph.microsoft.com/User.Read",
      authorize_params: {
        prompt: "consent",
        response_mode: "query"
      }
    }
end
