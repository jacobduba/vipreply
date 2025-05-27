Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, Rails.application.credentials.google_client_id, Rails.application.credentials.google_client_secret,
    {
      scope: "email, profile, https://www.googleapis.com/auth/gmail.readonly, https://www.googleapis.com/auth/gmail.send"
    }
end
