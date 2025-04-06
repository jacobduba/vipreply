# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Dashboard for Solid Queue
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "login" => "sessions#new", :as => :login
  delete "logout" => "sessions#destroy"

  # OmniAuth routes
  post "/auth/:provider/callback", to: "sessions#omniauth"
  get "/auth/:provider/callback", to: "sessions#omniauth"
  get "/auth/failure", to: redirect("/")

  # Legacy routes for backward compatibility
  get "auth/google_oauth2/callback", to: "sessions#google_auth"
  get "auth/microsoft_office365/callback", to: "sessions#microsoft_auth"

  # Add 'as: :microsoft_webhook_callback'
  post "/pubsub/microsoft_notifications", to: "pubsub#microsoft_notifications", as: :microsoft_webhook_callback

  # Inbox
  root "inboxes#index"
  get "update", to: "inboxes#update"

  resources :templates

  resources :topics do
    member do
      get "template_selector_dropdown"
      get "find_template"
      post "generate_reply"
      post "change_status"
      post "send_email"
      patch "change_templates_regenerate_response"
      post "update_templates_regenerate_reply"
      delete "remove_template/:template_id",
        action: :remove_template,
        as: :remove_template
    end
  end

  get "attachments/:id", to: "attachments#show", as: :attachment

  post "/pubsub/notifications", to: "pubsub#notifications"
end
