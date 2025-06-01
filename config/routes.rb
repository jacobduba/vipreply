# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live. [cite: 634]
  get "up" => "rails/health#show", :as => :rails_health_check

  # Dashboard for Solid Queue
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "login" => "sessions#new", :as => :login
  delete "logout" => "sessions#destroy"

  # OmniAuth routes
  post "/auth/:provider/callback", to: "sessions#omniauth"
  get "/auth/:provider/callback", to: "sessions#omniauth"
  get "/auth/failure", to: redirect("/")

  # Pub/Sub notifications
  # Microsoft Webhook
  post "/pubsub/microsoft_notifications", to: "pubsub#microsoft_notifications", as: :microsoft_webhook_callback
  # Gmail Pub/Sub (now provider-specific in the route)
  post "/pubsub/google/notifications", to: "pubsub#google_notifications" # Changed from pubsub#notifications


  # Inbox
  root "inboxes#index"
  get "update", to: "inboxes#update"

  resources :templates

  resources :topics do
    member do # [cite: 635]
      get "template_selector_dropdown"
      get "new_template_dropdown"
      post "create_template_dropdown"
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

  get "attachments/:id", to: "attachments#show", as: :attachment # [cite: 636]
end