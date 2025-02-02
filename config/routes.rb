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
  # Routes for Google authentication
  get "auth/:provider/callback", to: "sessions#google_auth"
  get "auth/failure", to: redirect("/")

  # Inbox
  root "inboxes#index"
  get "update", to: "inboxes#update"

  resources :templates

  resources :topics do
    member do
      get "regenerate_reply"
      get "template_selector"
      post "change_status"
      post "send_email"
      post "change_template/:template_id",
        to: "topics#change_template",
        as: :change_template
    end
  end

  get "attachments/:id", to: "attachments#show", as: :attachment

  post "/pubsub/notifications", to: "pubsub#notifications"
end
