Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.google_client_id,
    Rails.application.credentials.google_client_secret,
    {
      scope: "email, profile, https://www.googleapis.com/auth/gmail.modify"
    }

  provider :microsoft_office365,
    Rails.application.credentials.microsoft_client_id,
    Rails.application.credentials.microsoft_client_secret,
    {
      scope: "openid profile email offline_access https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/Mail.ReadWrite https://graph.microsoft.com/User.Read",
      authorize_params: {
        prompt: "consent"
      }
    }
end
