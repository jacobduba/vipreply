# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  root "marketing#landing"
  get "privacy", to: "marketing#privacy"
  get "terms", to: "marketing#terms"

  get "login", to: "sessions#new", as: :login
  delete "logout", to: "sessions#destroy"
  # Routes for Google authentication
  get "auth/:provider/callback", to: "sessions#google_auth"
  get "auth/failure", to: redirect("/")

  # Inbox
  scope :inbox do
    get "", to: "inboxes#index", as: :inbox
    get "update", to: "inboxes#update"

    resources :templates

    resources :topics do
      member do
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
  end

  # Attachments
  get "attachments/:id", to: "attachments#show", as: :attachment

  # Billing
  post "billing/subscribe"
  get "billing/success"
  get "billing/cancel"

  # Webhooks
  post "/pubsub/notifications", to: "pubsub#notifications"

  # Dashboard for Solid Queue
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
