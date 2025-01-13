# frozen_string_literal: true

Rails.application.routes.draw do
  get "topics/show"
  get "topic/show"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  get "login" => "sessions#new", :as => :login
  # post "login" => "sessions#create"
  delete "logout" => "sessions#destroy"
  # Routes for Google authentication
  get "auth/:provider/callback", to: "sessions#googleAuth"
  get "auth/failure", to: redirect("/")

  # root "models#index"

  resources :models do
    resources :examples
    post "generate_response", to: "models#generate_response"
  end

  root "inboxes#index"

  resources :templates

  resources :topics do
    member do
      get :regenerate_reply
    end
  end

  get "attachments/:id", to: "attachments#show", as: :attachment

  get "update", to: "inboxes#update"

  post "/pubsub/notifications", to: "pubsub#notifications"

  mount MissionControl::Jobs::Engine, at: "/jobs"
end
