Rails.application.configure do
  Stripe.api_key = Rails.application.credentials.stripe_secret_key
end